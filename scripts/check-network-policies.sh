#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-idp-local}"
APPS_NAMESPACE="${APPS_NAMESPACE:-apps}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
BLOCK_NAMESPACE="${BLOCK_NAMESPACE:-netpol-deny-test}"
SERVICE_NAME="${SERVICE_NAME:-demo-grpc}"
METRICS_PORT="${METRICS_PORT:-9090}"

APPS_CLIENT="netpol-apps-client"
OBS_CLIENT="netpol-observability-client"
BLOCK_CLIENT="netpol-block-client"

echo "============================================================"
echo "Check NetworkPolicy baseline"
echo "Context:           ${CONTEXT}"
echo "Apps namespace:    ${APPS_NAMESPACE}"
echo "Observability ns:  ${OBS_NAMESPACE}"
echo "Block test ns:     ${BLOCK_NAMESPACE}"
echo "Service:           ${SERVICE_NAME}"
echo "Metrics port:      ${METRICS_PORT}"
echo "============================================================"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${CONTEXT}" ]]; then
  echo "ERROR: expected Kubernetes context '${CONTEXT}', got '${CURRENT_CONTEXT}'."
  exit 1
fi

cleanup() {
  kubectl -n "${APPS_NAMESPACE}" delete pod "${APPS_CLIENT}" --ignore-not-found=true >/dev/null 2>&1 || true
  kubectl -n "${OBS_NAMESPACE}" delete pod "${OBS_CLIENT}" --ignore-not-found=true >/dev/null 2>&1 || true
  kubectl delete namespace "${BLOCK_NAMESPACE}" --ignore-not-found=true >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo
echo "ArgoCD application:"
kubectl -n argocd get application network-policies \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'

SYNC_STATUS="$(kubectl -n argocd get application network-policies -o jsonpath='{.status.sync.status}')"
HEALTH_STATUS="$(kubectl -n argocd get application network-policies -o jsonpath='{.status.health.status}')"

[[ "${SYNC_STATUS}" == "Synced" ]]
[[ "${HEALTH_STATUS}" == "Healthy" ]]
echo "OK: ArgoCD application network-policies is Synced/Healthy."

echo
echo "NetworkPolicies:"
kubectl get networkpolicy -n "${APPS_NAMESPACE}"

kubectl -n "${APPS_NAMESPACE}" get networkpolicy apps-default-deny-ingress >/dev/null
echo "OK: apps-default-deny-ingress exists."

kubectl -n "${APPS_NAMESPACE}" get networkpolicy demo-grpc-allow-ingress >/dev/null
echo "OK: demo-grpc-allow-ingress exists."

DEFAULT_DENY_POLICY_TYPES="$(
  kubectl -n "${APPS_NAMESPACE}" get networkpolicy apps-default-deny-ingress \
    -o jsonpath='{.spec.policyTypes[0]}'
)"
[[ "${DEFAULT_DENY_POLICY_TYPES}" == "Ingress" ]]
echo "OK: apps-default-deny-ingress isolates ingress traffic."

DEMO_GRPC_SELECTOR="$(
  kubectl -n "${APPS_NAMESPACE}" get networkpolicy demo-grpc-allow-ingress \
    -o jsonpath='{.spec.podSelector.matchLabels.app\.kubernetes\.io/name}'
)"
[[ "${DEMO_GRPC_SELECTOR}" == "demo-grpc" ]]
echo "OK: demo-grpc-allow-ingress selects demo-grpc pods."

echo
echo "Service:"
kubectl -n "${APPS_NAMESPACE}" get svc "${SERVICE_NAME}"

SERVICE_URL_APPS="http://${SERVICE_NAME}:${METRICS_PORT}/metrics"
SERVICE_URL_FQDN="http://${SERVICE_NAME}.${APPS_NAMESPACE}.svc.cluster.local:${METRICS_PORT}/metrics"

echo
echo "Cleaning up previous test clients..."
cleanup

echo
echo "Creating apps namespace client..."
kubectl -n "${APPS_NAMESPACE}" run "${APPS_CLIENT}" \
  --image=curlimages/curl:8.10.1 \
  --restart=Never \
  --command -- sleep 3600

kubectl -n "${APPS_NAMESPACE}" wait --for=condition=Ready "pod/${APPS_CLIENT}" --timeout=180s

echo
echo "Checking allowed traffic from apps namespace to demo-grpc metrics..."
kubectl -n "${APPS_NAMESPACE}" exec "${APPS_CLIENT}" -- \
  curl -fsS --max-time 5 "${SERVICE_URL_APPS}" >/dev/null

echo "OK: apps namespace client can reach demo-grpc metrics."

echo
echo "Creating observability namespace client..."
kubectl -n "${OBS_NAMESPACE}" run "${OBS_CLIENT}" \
  --image=curlimages/curl:8.10.1 \
  --restart=Never \
  --command -- sleep 3600

kubectl -n "${OBS_NAMESPACE}" wait --for=condition=Ready "pod/${OBS_CLIENT}" --timeout=180s

echo
echo "Checking allowed traffic from observability namespace to demo-grpc metrics..."
kubectl -n "${OBS_NAMESPACE}" exec "${OBS_CLIENT}" -- \
  curl -fsS --max-time 5 "${SERVICE_URL_FQDN}" >/dev/null

echo "OK: observability namespace client can reach demo-grpc metrics."

echo
echo "Creating blocked namespace client..."
kubectl create namespace "${BLOCK_NAMESPACE}"

kubectl -n "${BLOCK_NAMESPACE}" run "${BLOCK_CLIENT}" \
  --image=curlimages/curl:8.10.1 \
  --restart=Never \
  --command -- sleep 3600

kubectl -n "${BLOCK_NAMESPACE}" wait --for=condition=Ready "pod/${BLOCK_CLIENT}" --timeout=180s

echo
echo "Checking blocked traffic from unrelated namespace to demo-grpc metrics..."
if kubectl -n "${BLOCK_NAMESPACE}" exec "${BLOCK_CLIENT}" -- \
  curl -fsS --max-time 5 "${SERVICE_URL_FQDN}" >/dev/null
then
  echo "ERROR: unrelated namespace unexpectedly reached demo-grpc metrics."
  exit 1
fi

echo "OK: unrelated namespace cannot reach demo-grpc metrics."

echo
echo "Cleaning up test clients..."
cleanup
echo "OK: test clients removed."

echo
echo "============================================================"
echo "NetworkPolicy baseline validated successfully."
echo "============================================================"
