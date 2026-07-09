#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-idp-local}"
NAMESPACE="${NAMESPACE:-backstage}"
APP_NAME="${APP_NAME:-backstage}"
LOCAL_PORT="${LOCAL_PORT:-17007}"

echo "============================================================"
echo "Check Backstage stack"
echo "Context:   ${CONTEXT}"
echo "Namespace: ${NAMESPACE}"
echo "App:       ${APP_NAME}"
echo "URL:       http://127.0.0.1:${LOCAL_PORT}"
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
echo "Backstage workloads:"
kubectl -n "${NAMESPACE}" get deploy,pods,svc -o wide

echo
kubectl -n "${NAMESPACE}" rollout status deployment/backstage-postgresql --timeout=240s
kubectl -n "${NAMESPACE}" rollout status deployment/backstage --timeout=300s

echo
echo "Checking local port-forward UI and catalog API..."

kubectl -n "${NAMESPACE}" port-forward svc/backstage "${LOCAL_PORT}:7007" >/tmp/backstage-port-forward.log 2>&1 &
PF_PID="$!"

cleanup() {
  kill "${PF_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 5

for i in {1..30}; do
  if curl -fsS "http://127.0.0.1:${LOCAL_PORT}/healthcheck" >/tmp/backstage-healthcheck.txt; then
    break
  fi

  echo "Waiting for Backstage healthcheck... attempt ${i}/30"
  sleep 5
done

grep -qi "Backstage" /tmp/backstage-healthcheck.txt
echo "OK: Backstage UI is reachable."

echo
echo "Checking Backstage catalog API for demo-grpc component..."

COMPONENT_URL="http://127.0.0.1:${LOCAL_PORT}/api/catalog/entities/by-name/component/default/demo-grpc"
GROUP_URL="http://127.0.0.1:${LOCAL_PORT}/api/catalog/entities/by-name/group/default/platform-team"
API_URL="http://127.0.0.1:${LOCAL_PORT}/api/catalog/entities/by-name/api/default/demo-grpc-api"

curl -fsS "${COMPONENT_URL}" >/tmp/backstage-demo-grpc-component.json
grep -q '"kind":"Component"' /tmp/backstage-demo-grpc-component.json
grep -q '"name":"demo-grpc"' /tmp/backstage-demo-grpc-component.json
echo "OK: Component/demo-grpc is visible through the Backstage catalog API."

curl -fsS "${GROUP_URL}" >/tmp/backstage-platform-team-group.json
grep -q '"kind":"Group"' /tmp/backstage-platform-team-group.json
grep -q '"name":"platform-team"' /tmp/backstage-platform-team-group.json
echo "OK: Group/platform-team is visible through the Backstage catalog API."

curl -fsS "${API_URL}" >/tmp/backstage-demo-grpc-api.json
grep -q '"kind":"API"' /tmp/backstage-demo-grpc-api.json
grep -q '"name":"demo-grpc-api"' /tmp/backstage-demo-grpc-api.json
echo "OK: API/demo-grpc-api is visible through the Backstage catalog API."

echo
echo "============================================================"
echo "Backstage stack validated successfully."
echo "============================================================"
