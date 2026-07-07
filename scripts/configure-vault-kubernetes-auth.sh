#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-idp-local}"
VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"
VAULT_APP="${VAULT_APP:-vault}"
VAULT_AUTH_APP="${VAULT_AUTH_APP:-vault-kubernetes-auth}"
ROLE_NAME="${ROLE_NAME:-demo-grpc}"
POLICY_NAME="${POLICY_NAME:-demo-grpc-read}"
SECRET_PATH="${SECRET_PATH:-secret/demo-grpc/config}"

echo "============================================================"
echo "Configure Vault Kubernetes auth"
echo "Context:          ${CONTEXT}"
echo "Vault namespace:  ${VAULT_NAMESPACE}"
echo "Vault app:        ${VAULT_APP}"
echo "Auth app:         ${VAULT_AUTH_APP}"
echo "Role:             ${ROLE_NAME}"
echo "Policy:           ${POLICY_NAME}"
echo "Secret path:      ${SECRET_PATH}"
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
echo "Configuring Vault auth method, policy, role and demo secret..."

kubectl -n "${VAULT_NAMESPACE}" exec -i statefulset/vault -- sh -s <<'VAULT_SH'
set -eu

export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="root"

if vault auth list | grep -q '^kubernetes/'; then
  echo "Vault Kubernetes auth method already enabled."
else
  vault auth enable kubernetes
  echo "Vault Kubernetes auth method enabled."
fi

vault write auth/kubernetes/config \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  kubernetes_host="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT_HTTPS}" \
  kubernetes_ca_cert="$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)" \
  disable_iss_validation=true

vault kv put secret/demo-grpc/config \
  message="hello-from-vault" \
  owner="cloud-native-idp-platform" \
  purpose="kubernetes-auth-smoke-test" >/dev/null

cat >/tmp/demo-grpc-read.hcl <<'HCL'
path "secret/data/demo-grpc/config" {
  capabilities = ["read"]
}

path "secret/metadata/demo-grpc/config" {
  capabilities = ["read"]
}
HCL

vault policy write demo-grpc-read /tmp/demo-grpc-read.hcl

vault write auth/kubernetes/role/demo-grpc \
  bound_service_account_names="demo-grpc,vault-auth-smoke" \
  bound_service_account_namespaces="apps" \
  policies="demo-grpc-read" \
  ttl="1h"

vault read auth/kubernetes/role/demo-grpc
VAULT_SH

echo
echo "============================================================"
echo "Vault Kubernetes auth configured successfully."
echo "============================================================"
