#!/usr/bin/env bash
set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
LOCAL_GRAFANA_PORT="${LOCAL_GRAFANA_PORT:-3001}"
DASHBOARD_UID="${DASHBOARD_UID:-demo-grpc}"

echo "============================================================"
echo "Check demo-grpc Grafana dashboard"
echo "Context:        ${EXPECTED_CONTEXT}"
echo "Obs namespace:  ${OBS_NAMESPACE}"
echo "Dashboard UID:  ${DASHBOARD_UID}"
echo "============================================================"
echo

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${EXPECTED_CONTEXT}" ]]; then
  echo "ERROR: kubectl context mismatch."
  echo "Current:  ${CURRENT_CONTEXT}"
  echo "Expected: ${EXPECTED_CONTEXT}"
  exit 1
fi

echo "ArgoCD grafana-dashboards application:"
kubectl -n argocd get application grafana-dashboards

echo
echo "Dashboard ConfigMap:"
kubectl -n "${OBS_NAMESPACE}" get configmap demo-grpc-dashboard -o wide

echo
echo "ConfigMap labels:"
kubectl -n "${OBS_NAMESPACE}" get configmap demo-grpc-dashboard \
  -o jsonpath='{.metadata.labels}' && echo

echo
echo "Testing Grafana dashboard API..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/kube-prometheus-stack-grafana \
  "${LOCAL_GRAFANA_PORT}:80" >/tmp/grafana-dashboard-port-forward.log 2>&1 &
GRAFANA_PF_PID=$!

cleanup() {
  kill "${GRAFANA_PF_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 3

echo "Querying Grafana dashboard search API..."
curl -fsS \
  -u admin:admin \
  "http://localhost:${LOCAL_GRAFANA_PORT}/api/search?query=demo-grpc" \
  | grep -q "${DASHBOARD_UID}"
echo "Dashboard found in Grafana."

echo
echo "Querying dashboard by UID..."
curl -fsS \
  -u admin:admin \
  "http://localhost:${LOCAL_GRAFANA_PORT}/api/dashboards/uid/${DASHBOARD_UID}" \
  | grep -q "demo-grpc"
echo "Dashboard UID lookup OK."

echo
echo "============================================================"
echo "Grafana demo-grpc dashboard is provisioned and accessible."
echo "Open: http://localhost:3000/d/${DASHBOARD_UID}"
echo "============================================================"
