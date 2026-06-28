#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
LOCAL_PROMETHEUS_PORT="${LOCAL_PROMETHEUS_PORT:-19094}"

echo "============================================================"
echo "Check Loki metrics scraping"
echo "Context:              ${EXPECTED_CONTEXT}"
echo "Namespace:            ${OBS_NAMESPACE}"
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

echo "ArgoCD application:"
kubectl -n argocd get application loki-monitoring
echo

echo "Loki Service:"
kubectl -n "${OBS_NAMESPACE}" get svc loki -o wide
echo

echo "Loki ServiceMonitor:"
kubectl -n "${OBS_NAMESPACE}" get servicemonitor loki -o wide
echo

echo "Starting Prometheus port-forward..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/kube-prometheus-stack-prometheus "${LOCAL_PROMETHEUS_PORT}:9090" >/tmp/loki-metrics-prometheus-port-forward.log 2>&1 &
PROM_PF_PID=$!

cleanup() {
  kill "${PROM_PF_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 4

echo "Checking Prometheus readiness..."
curl -fsS "http://127.0.0.1:${LOCAL_PROMETHEUS_PORT}/-/ready" >/dev/null
echo "Prometheus ready OK."
echo

query_prometheus() {
  local query="$1"
  curl -G -s "http://127.0.0.1:${LOCAL_PROMETHEUS_PORT}/api/v1/query" \
    --data-urlencode "query=${query}"
}

wait_for_query_value() {
  local label="$1"
  local query="$2"
  local expected="$3"

  echo "Waiting for: ${label}"

  for attempt in {1..24}; do
    RESPONSE="$(query_prometheus "${query}")"

    if echo "${RESPONSE}" | grep -q "\"${expected}\""; then
      echo "OK: ${label}"
      return 0
    fi

    echo "  attempt ${attempt}/24: not ready yet"
    sleep 10
  done

  echo "ERROR: query did not return expected value."
  echo "Label: ${label}"
  echo "Query: ${query}"
  echo "Expected: ${expected}"
  echo "Last response:"
  echo "${RESPONSE}" | head -c 3000
  echo
  exit 1
}

wait_for_non_empty_result() {
  local label="$1"
  local query="$2"

  echo "Waiting for metric series: ${label}"

  for attempt in {1..24}; do
    RESPONSE="$(query_prometheus "${query}")"

    if ! echo "${RESPONSE}" | grep -q '"result":\[\]'; then
      echo "OK: ${label}"
      return 0
    fi

    echo "  attempt ${attempt}/24: not found yet"
    sleep 10
  done

  echo "ERROR: no metric series found."
  echo "Label: ${label}"
  echo "Query: ${query}"
  echo "Last response:"
  echo "${RESPONSE}" | head -c 3000
  echo
  exit 1
}

wait_for_query_value \
  "Loki target up" \
  'max(up{namespace="observability", service="loki"})' \
  '1'

wait_for_non_empty_result \
  "Loki-owned loki_* metrics" \
  'count({__name__=~"loki_.*", namespace="observability", service="loki"})'

echo

echo "Sample Loki target:"
query_prometheus 'up{namespace="observability", service="loki"}'
echo
echo

echo "Sample Loki metrics count:"
query_prometheus 'count({__name__=~"loki_.*", namespace="observability", service="loki"})'
echo
echo

echo "============================================================"
echo "Loki metrics are scraped by Prometheus."
echo "============================================================"
