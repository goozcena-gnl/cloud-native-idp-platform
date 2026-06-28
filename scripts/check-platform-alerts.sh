#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
LOCAL_PROMETHEUS_PORT="${LOCAL_PROMETHEUS_PORT:-9093}"

ALERT_NAMES=(
  DemoGrpcDown
  GrafanaDown
  LokiDown
  ArgoCDAppOutOfSync
  ArgoCDAppUnhealthy
  ArgoCDApplicationControllerMetricsDown
  ArgoCDRepoServerMetricsDown
  ArgoCDServerMetricsDown
)

echo "============================================================"
echo "Check platform Prometheus alerts"
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
kubectl -n argocd get application platform-alerts
echo

echo "PrometheusRule:"
kubectl -n "${OBS_NAMESPACE}" get prometheusrule platform-alerts -o wide
echo

echo "Starting Prometheus port-forward..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/kube-prometheus-stack-prometheus "${LOCAL_PROMETHEUS_PORT}:9090" >/tmp/platform-alerts-prometheus-port-forward.log 2>&1 &
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

echo "Waiting for alert rules to be loaded..."
for attempt in {1..24}; do
  RULES_RESPONSE="$(
    curl -G -s "http://localhost:${LOCAL_PROMETHEUS_PORT}/api/v1/rules" \
      --data-urlencode 'type=alert'
  )"

  missing=0
  for alert in "${ALERT_NAMES[@]}"; do
    if ! echo "${RULES_RESPONSE}" | grep -q "\"name\":\"${alert}\""; then
      missing=1
      break
    fi
  done

  if [[ "${missing}" -eq 0 ]]; then
    echo "All platform alert rules are loaded."
    break
  fi

  echo "  attempt ${attempt}/24: rules not loaded yet"
  sleep 10
done

if [[ "${missing}" -ne 0 ]]; then
  echo "ERROR: Some alert rules were not loaded."
  echo "Expected alerts:"
  printf '%s\n' "${ALERT_NAMES[@]}"
  exit 1
fi

echo

query_prometheus() {
  local query="$1"
  curl -G -s "http://localhost:${LOCAL_PROMETHEUS_PORT}/api/v1/query" \
    --data-urlencode "query=${query}"
}

assert_value() {
  local label="$1"
  local query="$2"
  local expected="$3"

  echo "Checking expression: ${label}"
  RESPONSE="$(query_prometheus "${query}")"

  if ! echo "${RESPONSE}" | grep -q "\"${expected}\""; then
    echo "ERROR: unexpected query result for ${label}"
    echo "Query: ${query}"
    echo "Expected value fragment: ${expected}"
    echo "Response:"
    echo "${RESPONSE}" | head -c 3000
    echo
    exit 1
  fi

  echo "OK: ${label}"
}

assert_value \
  "demo-grpc up" \
  'max(up{namespace="apps", service="demo-grpc"})' \
  '1'

assert_value \
  "Grafana up" \
  'max(up{namespace="observability", service="kube-prometheus-stack-grafana"})' \
  '1'

assert_value \
  "Loki up" \
  'max(up{namespace="observability", service="loki"})' \
  '1'

assert_value \
  "ArgoCD application-controller metrics up" \
  'max(up{namespace="argocd", service="argocd-application-controller-metrics"})' \
  '1'

assert_value \
  "ArgoCD repo-server metrics up" \
  'max(up{namespace="argocd", service="argocd-repo-server-metrics"})' \
  '1'

assert_value \
  "ArgoCD server metrics up" \
  'max(up{namespace="argocd", service="argocd-server-metrics"})' \
  '1'

assert_value \
  "ArgoCD OutOfSync apps" \
  'sum(argocd_app_info{project="idp-platform", sync_status!="Synced"}) or vector(0)' \
  '0'

assert_value \
  "ArgoCD unhealthy apps" \
  'sum(argocd_app_info{project="idp-platform", health_status!="Healthy"}) or vector(0)' \
  '0'

echo
echo "Checking currently firing platform alerts..."
ALERTS_RESPONSE="$(curl -G -s "http://localhost:${LOCAL_PROMETHEUS_PORT}/api/v1/alerts")"

for alert in "${ALERT_NAMES[@]}"; do
  if echo "${ALERTS_RESPONSE}" | grep -q "\"alertname\":\"${alert}\""; then
    echo "ERROR: platform alert is currently firing: ${alert}"
    echo "${ALERTS_RESPONSE}" | head -c 3000
    echo
    exit 1
  fi
done

echo "No platform alert is firing."
echo

echo "============================================================"
echo "Platform Prometheus alerts are loaded and healthy."
echo "============================================================"
