#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
APP_NAMESPACE="${APP_NAMESPACE:-apps}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
APP_NAME="${APP_NAME:-demo-grpc}"
LOCAL_GRPC_PORT="${LOCAL_GRPC_PORT:-50052}"
LOCAL_PROMETHEUS_PORT="${LOCAL_PROMETHEUS_PORT:-19100}"
SLO_CALLS="${SLO_CALLS:-20}"

echo "============================================================"
echo "Check demo-grpc SLO recording rules"
echo "Context:              ${EXPECTED_CONTEXT}"
echo "App namespace:        ${APP_NAMESPACE}"
echo "Obs namespace:        ${OBS_NAMESPACE}"
echo "App:                  ${APP_NAME}"
echo "Local gRPC port:      ${LOCAL_GRPC_PORT}"
echo "Local Prometheus port:${LOCAL_PROMETHEUS_PORT}"
echo "SLO calls:            ${SLO_CALLS}"
echo "============================================================"
echo

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${EXPECTED_CONTEXT}" ]]; then
  echo "ERROR: kubectl context mismatch."
  echo "Current:  ${CURRENT_CONTEXT}"
  echo "Expected: ${EXPECTED_CONTEXT}"
  exit 1
fi

echo "ArgoCD applications:"
kubectl -n argocd get applications demo-grpc platform-slo kube-prometheus-stack \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'
echo

echo "PrometheusRule:"
kubectl -n "${OBS_NAMESPACE}" get prometheusrule demo-grpc-slo-rules
echo

echo "Checking demo-grpc rollout..."
kubectl -n "${APP_NAMESPACE}" rollout status "deploy/${APP_NAME}"
echo

echo "Starting demo-grpc port-forward..."
kubectl -n "${APP_NAMESPACE}" port-forward "svc/${APP_NAME}" "${LOCAL_GRPC_PORT}:50051" >/tmp/check-demo-grpc-slo-grpc-port-forward.log 2>&1 &
GRPC_PF_PID=$!

echo "Starting Prometheus port-forward..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/kube-prometheus-stack-prometheus "${LOCAL_PROMETHEUS_PORT}:9090" >/tmp/check-demo-grpc-slo-prometheus-port-forward.log 2>&1 &
PROM_PF_PID=$!

cleanup() {
  kill "${GRPC_PF_PID}" >/dev/null 2>&1 || true
  kill "${PROM_PF_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

wait_for_url() {
  local label="$1"
  local url="$2"

  echo "Waiting for ${label}..."

  for attempt in {1..30}; do
    if curl -fsS "${url}" >/dev/null 2>&1; then
      echo "OK: ${label}"
      return 0
    fi

    echo "  attempt ${attempt}/30: not ready yet"
    sleep 2
  done

  echo "ERROR: ${label} did not become ready."
  echo
  echo "gRPC port-forward log:"
  cat /tmp/check-demo-grpc-slo-grpc-port-forward.log || true
  echo
  echo "Prometheus port-forward log:"
  cat /tmp/check-demo-grpc-slo-prometheus-port-forward.log || true
  exit 1
}

wait_for_url "Prometheus readiness" "http://127.0.0.1:${LOCAL_PROMETHEUS_PORT}/-/ready"
sleep 3

echo "Generating demo-grpc traffic..."
for i in $(seq 1 "${SLO_CALLS}"); do
  echo "  gRPC health call ${i}/${SLO_CALLS}"
  (
    cd services/demo-grpc
    go run ./cmd/healthcheck -addr "localhost:${LOCAL_GRPC_PORT}" >/dev/null
  )
done
echo "OK: demo-grpc traffic generated."
echo

echo "Waiting for Prometheus recording rules..."
sleep 45

query_prometheus() {
  local query="$1"
  curl -G -fsS "http://127.0.0.1:${LOCAL_PROMETHEUS_PORT}/api/v1/query" \
    --data-urlencode "query=${query}"
}

assert_query_has_result() {
  local label="$1"
  local query="$2"

  echo "Checking ${label}..."
  local response
  response="$(query_prometheus "${query}")"
  echo "${response}"

  RESPONSE="${response}" LABEL="${label}" python - <<'PY'
import json
import os
import sys

label = os.environ["LABEL"]
data = json.loads(os.environ["RESPONSE"])
result = data.get("data", {}).get("result", [])

if not result:
    sys.exit(f"ERROR: {label} returned no result.")

print(f"OK: {label} returned {len(result)} result(s).")
PY
  echo
}

assert_query_value_ge() {
  local label="$1"
  local query="$2"
  local min_value="$3"

  echo "Checking ${label} >= ${min_value}..."
  local response
  response="$(query_prometheus "${query}")"
  echo "${response}"

  RESPONSE="${response}" LABEL="${label}" MIN_VALUE="${min_value}" python - <<'PY'
import json
import os
import sys

label = os.environ["LABEL"]
min_value = float(os.environ["MIN_VALUE"])
data = json.loads(os.environ["RESPONSE"])
result = data.get("data", {}).get("result", [])

if not result:
    sys.exit(f"ERROR: {label} returned no result.")

value = float(result[0].get("value", [None, "0"])[1])

if value < min_value:
    sys.exit(f"ERROR: {label} expected >= {min_value}, got {value}.")

print(f"OK: {label} = {value}.")
PY
  echo
}

assert_query_value_between() {
  local label="$1"
  local query="$2"
  local min_value="$3"
  local max_value="$4"

  echo "Checking ${label} between ${min_value} and ${max_value}..."
  local response
  response="$(query_prometheus "${query}")"
  echo "${response}"

  RESPONSE="${response}" LABEL="${label}" MIN_VALUE="${min_value}" MAX_VALUE="${max_value}" python - <<'PY'
import json
import os
import sys

label = os.environ["LABEL"]
min_value = float(os.environ["MIN_VALUE"])
max_value = float(os.environ["MAX_VALUE"])
data = json.loads(os.environ["RESPONSE"])
result = data.get("data", {}).get("result", [])

if not result:
    sys.exit(f"ERROR: {label} returned no result.")

value = float(result[0].get("value", [None, "0"])[1])

if value < min_value or value > max_value:
    sys.exit(f"ERROR: {label} expected between {min_value} and {max_value}, got {value}.")

print(f"OK: {label} = {value}.")
PY
  echo
}

assert_query_value_between \
  "availability target" \
  'demo_grpc:slo:availability_target{service="demo-grpc", slo="availability"}' \
  "0.995" \
  "0.995"

assert_query_value_between \
  "error budget ratio" \
  'demo_grpc:slo:error_budget_ratio{service="demo-grpc", slo="availability"}' \
  "0.005" \
  "0.005"

assert_query_value_ge \
  "request rate 5m" \
  'demo_grpc:grpc_request_rate5m' \
  "0"

assert_query_value_between \
  "success ratio 5m" \
  'demo_grpc:grpc_success_ratio5m' \
  "0" \
  "1"

assert_query_value_between \
  "error ratio 5m" \
  'demo_grpc:grpc_error_ratio5m' \
  "0" \
  "1"

assert_query_value_ge \
  "latency p95 seconds 5m" \
  'demo_grpc:grpc_latency_p95_seconds5m' \
  "0"

assert_query_value_ge \
  "error budget burn rate 5m" \
  'demo_grpc:slo:error_budget_burn_rate5m{service="demo-grpc", slo="availability"}' \
  "0"

assert_query_has_result \
  "all demo-grpc SLO recording rules" \
  '{__name__=~"demo_grpc:.*", job!=""} or {__name__=~"demo_grpc:.*"}'

echo "============================================================"
echo "demo-grpc SLO recording rules are loaded and queryable."
echo "============================================================"
