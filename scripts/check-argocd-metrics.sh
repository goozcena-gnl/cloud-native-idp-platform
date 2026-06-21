#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
LOCAL_PROMETHEUS_PORT="${LOCAL_PROMETHEUS_PORT:-9092}"

echo "============================================================"
echo "Check ArgoCD metrics scraping"
echo "Context:              ${EXPECTED_CONTEXT}"
echo "ArgoCD namespace:     ${ARGOCD_NAMESPACE}"
echo "Observability ns:     ${OBS_NAMESPACE}"
echo "Local Prometheus port:${LOCAL_PROMETHEUS_PORT}"
echo "============================================================"
echo

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${EXPECTED_CONTEXT}" ]]; then
  echo "ERROR: kubectl context mismatch."
  echo "Current:  ${CURRENT_CONTEXT}"
  echo "Expected: ${EXPECTED_CONTEXT}"
  exit 1
fi

echo "ArgoCD monitoring application:"
kubectl -n argocd get application argocd-monitoring
echo

echo "ArgoCD metrics services:"
kubectl -n "${ARGOCD_NAMESPACE}" get svc -l idp.platform/monitoring=argocd -o wide
echo

echo "ArgoCD ServiceMonitor:"
kubectl -n "${ARGOCD_NAMESPACE}" get servicemonitor argocd-metrics -o wide
echo

echo "Starting Prometheus port-forward..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/kube-prometheus-stack-prometheus "${LOCAL_PROMETHEUS_PORT}:9090" >/tmp/argocd-prometheus-port-forward.log 2>&1 &
PROM_PF_PID=$!

cleanup() {
  kill "${PROM_PF_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 4

echo "Checking Prometheus readiness..."
curl -fsS "http://localhost:${LOCAL_PROMETHEUS_PORT}/-/ready" >/dev/null
echo "Prometheus ready OK."
echo

query_prometheus() {
  local query="$1"
  curl -G -s "http://localhost:${LOCAL_PROMETHEUS_PORT}/api/v1/query" \
    --data-urlencode "query=${query}"
}

wait_for_metric() {
  local label="$1"
  local query="$2"
  local expected="$3"

  echo "Waiting for metric: ${label}"

  for attempt in {1..24}; do
    RESPONSE="$(query_prometheus "${query}")"

    if echo "${RESPONSE}" | grep -q "${expected}"; then
      echo "OK: ${label}"
      return 0
    fi

    echo "  attempt ${attempt}/24: not found yet"
    sleep 10
  done

  echo "ERROR: Metric not found: ${label}"
  echo "Query: ${query}"
  echo "Last response:"
  echo "${RESPONSE}" | head -c 3000
  echo
  exit 1
}

wait_for_metric \
  "argocd_app_info from application-controller" \
  'argocd_app_info' \
  'demo-grpc'

wait_for_metric \
  "argocd_info from argocd-server" \
  'argocd_info' \
  'v3.4.3'

wait_for_metric \
  "argocd_git_request_duration_seconds_count from repo-server" \
  'argocd_git_request_duration_seconds_count' \
  'cloud-native-idp-platform'

echo

echo "Sample ArgoCD app info:"
query_prometheus 'argocd_app_info' | head -c 1600
echo
echo

echo "============================================================"
echo "ArgoCD metrics are scraped by Prometheus."
echo "============================================================"
