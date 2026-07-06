#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-idp-local}"
NAMESPACE="${NAMESPACE:-vault}"
APP_NAME="${APP_NAME:-vault}"

echo "============================================================"
echo "Check Vault stack"
echo "Context:   ${CONTEXT}"
echo "Namespace: ${NAMESPACE}"
echo "App:       ${APP_NAME}"
echo "============================================================"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${CONTEXT}" ]]; then
  echo "ERROR: expected Kubernetes context '${CONTEXT}', got '${CURRENT_CONTEXT}'."
  exit 1
fi

echo
echo "ArgoCD application:"
kubectl -n argocd get application "${APP_NAME}" \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'

sync_status="$(kubectl -n argocd get application "${APP_NAME}" -o jsonpath='{.status.sync.status}')"
health_status="$(kubectl -n argocd get application "${APP_NAME}" -o jsonpath='{.status.health.status}')"

[[ "${sync_status}" == "Synced" ]]
[[ "${health_status}" == "Healthy" ]]

echo "OK: ArgoCD application ${APP_NAME} is Synced/Healthy."

echo
echo "Namespace:"
kubectl get namespace "${NAMESPACE}" --show-labels

echo
echo "Vault workloads:"
kubectl -n "${NAMESPACE}" get deploy,statefulset,pods,svc -o wide

echo
echo "Checking Vault StatefulSet readiness..."
kubectl -n "${NAMESPACE}" wait \
  --for=condition=Ready \
  pod \
  -l app.kubernetes.io/instance=vault,app.kubernetes.io/name=vault,component=server \
  --timeout=240s

desired_replicas="$(kubectl -n "${NAMESPACE}" get statefulset vault -o jsonpath='{.spec.replicas}')"
ready_replicas="$(kubectl -n "${NAMESPACE}" get statefulset vault -o jsonpath='{.status.readyReplicas}')"
ready_replicas="${ready_replicas:-0}"

[[ "${ready_replicas}" == "${desired_replicas}" ]]

echo "OK: Vault StatefulSet has ${ready_replicas}/${desired_replicas} ready replicas."

if kubectl -n "${NAMESPACE}" get deployment vault-agent-injector >/dev/null 2>&1; then
  kubectl -n "${NAMESPACE}" rollout status deployment/vault-agent-injector --timeout=240s
  echo "OK: Vault Agent Injector deployment rolled out."
fi

echo
echo "Vault status:"
kubectl -n "${NAMESPACE}" exec statefulset/vault -- vault status

echo
echo "Vault dev mode smoke test:"
kubectl -n "${NAMESPACE}" exec statefulset/vault -- sh -c '
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root
vault kv put secret/idp-smoke-test value=ok >/dev/null
vault kv get -field=value secret/idp-smoke-test
'

echo
echo "OK: Vault can write and read a dev secret."

echo
echo "============================================================"
echo "Vault stack validated successfully."
echo "============================================================"
