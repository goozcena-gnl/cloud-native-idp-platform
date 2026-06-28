#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
LOCAL_GRAFANA_PORT="${LOCAL_GRAFANA_PORT:-3005}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_SECRET="${GRAFANA_SECRET:-kube-prometheus-stack-grafana}"
DASHBOARD_UID="${DASHBOARD_UID:-demo-grpc-sre}"

echo "============================================================"
echo "Check Grafana SRE summary dashboard"
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
kubectl -n "${OBS_NAMESPACE}" get configmap demo-grpc-sre-dashboard -o wide
echo

if [[ -z "${GRAFANA_PASSWORD:-}" ]]; then
  GRAFANA_PASSWORD="$(
    kubectl -n "${OBS_NAMESPACE}" get secret "${GRAFANA_SECRET}" \
      -o jsonpath='{.data.admin-password}' | base64 -d
  )"
fi

echo "Starting Grafana port-forward..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/kube-prometheus-stack-grafana "${LOCAL_GRAFANA_PORT}:80" >/tmp/grafana-sre-dashboard-port-forward.log 2>&1 &
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

echo "Checking Prometheus datasource..."
curl -fsS \
  -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
  "http://localhost:${LOCAL_GRAFANA_PORT}/api/datasources/uid/prometheus" \
  | grep -q '"name":"Prometheus"'
echo "Prometheus datasource OK."
echo

echo "Checking Loki datasource..."
curl -fsS \
  -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
  "http://localhost:${LOCAL_GRAFANA_PORT}/api/datasources/uid/loki" \
  | grep -q '"name":"Loki"'
echo "Loki datasource OK."
echo

echo "Checking SRE dashboard..."
DASHBOARD_RESPONSE="$(
  curl -fsS \
    -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
    "http://localhost:${LOCAL_GRAFANA_PORT}/api/dashboards/uid/${DASHBOARD_UID}"
)"

echo "${DASHBOARD_RESPONSE}" | grep -q "\"uid\":\"${DASHBOARD_UID}\""
echo "${DASHBOARD_RESPONSE}" | grep -q "Service Up"
echo "${DASHBOARD_RESPONSE}" | grep -q "Request rate"
echo "${DASHBOARD_RESPONSE}" | grep -q "P95 latency"
echo "${DASHBOARD_RESPONSE}" | grep -q "ERROR logs"
echo "${DASHBOARD_RESPONSE}" | grep -q "Recent application logs"
echo "${DASHBOARD_RESPONSE}" | grep -q "GitOps Apps Total"
echo "${DASHBOARD_RESPONSE}" | grep -q "GitOps Apps Synced"
echo "${DASHBOARD_RESPONSE}" | grep -q "GitOps Apps Healthy"
echo "${DASHBOARD_RESPONSE}" | grep -q "OutOfSync Apps"
echo "${DASHBOARD_RESPONSE}" | grep -q "Unhealthy Apps"
echo "${DASHBOARD_RESPONSE}" | grep -q "ArgoCD version"
echo "${DASHBOARD_RESPONSE}" | grep -q "Git request rate by type"
echo "${DASHBOARD_RESPONSE}" | grep -q "Git request P95 by type"
echo "${DASHBOARD_RESPONSE}" | grep -q "ArgoCD applications table"
echo "${DASHBOARD_RESPONSE}" | grep -q "Logging backend overview"
echo "${DASHBOARD_RESPONSE}" | grep -q "Loki backend up"
echo "${DASHBOARD_RESPONSE}" | grep -q "Loki metrics count"
echo "${DASHBOARD_RESPONSE}" | grep -q "Loki 5xx rate"
echo "${DASHBOARD_RESPONSE}" | grep -q "Loki ingested bytes/sec"
echo "${DASHBOARD_RESPONSE}" | grep -q "Loki ingested lines/sec"
echo "${DASHBOARD_RESPONSE}" | grep -q "Loki ingester streams"
echo "${DASHBOARD_RESPONSE}" | grep -q "Loki memory usage"
echo "${DASHBOARD_RESPONSE}" | grep -q "Loki request rate by route/status"
echo "${DASHBOARD_RESPONSE}" | grep -q "Loki request P95 by route"

echo "Grafana SRE dashboard OK."
echo

echo "============================================================"
echo "Grafana SRE summary dashboard is provisioned and reachable."
echo "============================================================"
