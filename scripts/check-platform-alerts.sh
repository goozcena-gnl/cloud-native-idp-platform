#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
LOCAL_PROMETHEUS_PORT="${LOCAL_PROMETHEUS_PORT:-9093}"

ALERT_NAMES=(
  DemoGrpcSLOFastBurn
  DemoGrpcSLOSlowBurn
  DemoGrpcDown
  GrafanaDown
  LokiDown
  TempoDown
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

echo "Checking alert runbook_url annotations..."
RULES_RESPONSE_FILE="$(mktemp)"
printf '%s' "${RULES_RESPONSE}" > "${RULES_RESPONSE_FILE}"
python - "${RULES_RESPONSE_FILE}" <<'PYRUNBOOKS'
import json
import sys

expected_alerts = [
    "DemoGrpcSLOFastBurn",
    "DemoGrpcSLOSlowBurn",
    "DemoGrpcDown",
    "GrafanaDown",
    "LokiDown",
    "TempoDown",
    "ArgoCDAppOutOfSync",
    "ArgoCDAppUnhealthy",
    "ArgoCDApplicationControllerMetricsDown",
    "ArgoCDRepoServerMetricsDown",
    "ArgoCDServerMetricsDown",
]

with open(sys.argv[1], "r", encoding="utf-8") as f:
    payload = json.load(f)

found = {}

for group in payload.get("data", {}).get("groups", []):
    for rule in group.get("rules", []):
        name = rule.get("name")
        if name in expected_alerts:
            annotations = rule.get("annotations", {}) or {}
            found[name] = bool(annotations.get("runbook_url"))

missing = [name for name in expected_alerts if not found.get(name)]

if missing:
    print("ERROR: missing runbook_url annotations for:")
    for name in missing:
        print(f"- {name}")
    sys.exit(1)

print(f"Alert runbook_url annotations OK ({len(expected_alerts)}/{len(expected_alerts)}).")
PYRUNBOOKS
rm -f "${RULES_RESPONSE_FILE}"
echo

assert_value() {
  local label="$1"
  local query="$2"
  local expected="$3"

  echo "Checking expression: ${label}"

  local response
  response="$(curl -G -s "http://127.0.0.1:${LOCAL_PROMETHEUS_PORT}/api/v1/query" \
    --data-urlencode "query=${query}")"

  if echo "${response}" | grep -q "\"${expected}\""; then
    echo "OK: ${label}"
    return 0
  fi

  echo "ERROR: expression did not return expected value."
  echo "Label:    ${label}"
  echo "Query:    ${query}"
  echo "Expected: ${expected}"
  echo "Response:"
  echo "${response}" | head -c 3000
  echo
  exit 1
}

assert_value \
  "demo-grpc up" \
  'max(up{namespace="apps", service="demo-grpc"})' \
  '1'

assert_value \
  "demo-grpc SLO fast burn inactive" \
  'demo_grpc:slo:error_budget_burn_rate5m{service="demo-grpc", slo="availability"} < 14.4' \
  '1'

assert_value \
  "demo-grpc SLO slow burn inactive" \
  'demo_grpc:slo:error_budget_burn_rate5m{service="demo-grpc", slo="availability"} < 3' \
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
  "Tempo up" \
  'max(up{namespace="observability", service="tempo"})' \
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
