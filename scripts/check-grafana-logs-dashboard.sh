#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
LOCAL_GRAFANA_PORT="${LOCAL_GRAFANA_PORT:-3003}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_SECRET="${GRAFANA_SECRET:-kube-prometheus-stack-grafana}"
DASHBOARD_UID="${DASHBOARD_UID:-demo-grpc-logs}"

echo "============================================================"
echo "Check Grafana logs dashboard"
echo "Context:           ${EXPECTED_CONTEXT}"
echo "Namespace:         ${OBS_NAMESPACE}"
echo "Grafana local port:${LOCAL_GRAFANA_PORT}"
echo "Dashboard UID:     ${DASHBOARD_UID}"
echo "============================================================"
echo

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${EXPECTED_CONTEXT}" ]]; then
  echo "ERROR: kubectl context mismatch."
  echo "Current:  ${CURRENT_CONTEXT}"
  echo "Expected: ${EXPECTED_CONTEXT}"
  exit 1
fi

echo "ArgoCD application:"
kubectl -n argocd get application grafana-dashboards
echo

echo "Dashboard ConfigMap:"
kubectl -n "${OBS_NAMESPACE}" get configmap demo-grpc-logs-dashboard -o wide
echo

echo "Loki datasource ConfigMap:"
kubectl -n "${OBS_NAMESPACE}" get configmap loki-datasource -o wide
echo

if [[ -z "${GRAFANA_PASSWORD:-}" ]]; then
  GRAFANA_PASSWORD="$(
    kubectl -n "${OBS_NAMESPACE}" get secret "${GRAFANA_SECRET}" \
      -o jsonpath='{.data.admin-password}' | base64 -d
  )"
fi

echo "Starting Grafana port-forward..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/kube-prometheus-stack-grafana "${LOCAL_GRAFANA_PORT}:80" >/tmp/grafana-logs-dashboard-port-forward.log 2>&1 &
GRAFANA_PF_PID=$!

cleanup() {
  kill "${GRAFANA_PF_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 4

echo "Checking Grafana health..."
curl -fsS "http://localhost:${LOCAL_GRAFANA_PORT}/api/health" >/dev/null
echo "Grafana health OK."
echo

echo "Checking Loki datasource..."
curl -fsS \
  -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
  "http://localhost:${LOCAL_GRAFANA_PORT}/api/datasources/uid/loki" \
  | grep -q '"name":"Loki"'
echo "Loki datasource OK."
echo

echo "Checking logs dashboard..."
DASHBOARD_RESPONSE="$(
  curl -fsS \
    -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
    "http://localhost:${LOCAL_GRAFANA_PORT}/api/dashboards/uid/${DASHBOARD_UID}"
)"

echo "${DASHBOARD_RESPONSE}" | grep -q "\"uid\":\"${DASHBOARD_UID}\""
echo "${DASHBOARD_RESPONSE}" | grep -q "\"name\":\"namespace\""
echo "${DASHBOARD_RESPONSE}" | grep -q "\"name\":\"pod\""
echo "${DASHBOARD_RESPONSE}" | grep -q "\"name\":\"container\""

echo "Grafana logs dashboard OK."
echo "Grafana logs dashboard variables OK."
echo

echo "============================================================"
echo "Grafana logs dashboard is provisioned and reachable."
echo "============================================================"
