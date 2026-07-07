#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-idp-local}"
VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"
APP_NAMESPACE="${APP_NAMESPACE:-apps}"
VAULT_APP="${VAULT_APP:-vault}"
VAULT_AUTH_APP="${VAULT_AUTH_APP:-vault-kubernetes-auth}"
SMOKE_SERVICE_ACCOUNT="${SMOKE_SERVICE_ACCOUNT:-vault-auth-smoke}"
ROLE_NAME="${ROLE_NAME:-demo-grpc}"
EXPECTED_VALUE="${EXPECTED_VALUE:-hello-from-vault}"

echo "============================================================"
echo "Check Vault Kubernetes auth"
echo "Context:               ${CONTEXT}"
echo "Vault namespace:       ${VAULT_NAMESPACE}"
echo "App namespace:         ${APP_NAMESPACE}"
echo "Smoke ServiceAccount:  ${SMOKE_SERVICE_ACCOUNT}"
echo "Vault role:            ${ROLE_NAME}"
echo "============================================================"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${CONTEXT}" ]]; then
  echo "ERROR: expected Kubernetes context '${CONTEXT}', got '${CURRENT_CONTEXT}'."
  exit 1
fi

echo
echo "ArgoCD applications:"
kubectl -n argocd get application "${VAULT_APP}" "${VAULT_AUTH_APP}" \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'

for app in "${VAULT_APP}" "${VAULT_AUTH_APP}"; do
  sync_status="$(kubectl -n argocd get application "${app}" -o jsonpath='{.status.sync.status}')"
  health_status="$(kubectl -n argocd get application "${app}" -o jsonpath='{.status.health.status}')"

  [[ "${sync_status}" == "Synced" ]]
  [[ "${health_status}" == "Healthy" ]]

  echo "OK: ArgoCD application ${app} is Synced/Healthy."
done

echo
echo "ServiceAccount:"
kubectl -n "${APP_NAMESPACE}" get serviceaccount "${SMOKE_SERVICE_ACCOUNT}"

echo
echo "ClusterRoleBinding:"
kubectl get clusterrolebinding vault-token-reviewer

echo
echo "Creating short-lived Kubernetes token..."
JWT="$(kubectl -n "${APP_NAMESPACE}" create token "${SMOKE_SERVICE_ACCOUNT}" --duration=10m)"

if [[ -z "${JWT}" ]]; then
  echo "ERROR: generated Kubernetes token is empty."
  exit 1
fi

echo "OK: Kubernetes token generated."

echo
echo "Authenticating to Vault with Kubernetes auth and reading secret..."

VALUE="$(
kubectl -n "${VAULT_NAMESPACE}" exec -i statefulset/vault -- sh -s <<VAULT_SH
set -eu

export VAULT_ADDR="http://127.0.0.1:8200"
CLIENT_TOKEN="\$(vault write -field=token auth/kubernetes/login role="${ROLE_NAME}" jwt="${JWT}")"

VAULT_TOKEN="\${CLIENT_TOKEN}" vault kv get -field=message secret/demo-grpc/config
VAULT_SH
)"

echo "Vault secret value: ${VALUE}"

[[ "${VALUE}" == "${EXPECTED_VALUE}" ]]

echo "OK: Kubernetes-authenticated Vault token can read the expected secret."

echo
echo "============================================================"
echo "Vault Kubernetes auth validated successfully."
echo "============================================================"
