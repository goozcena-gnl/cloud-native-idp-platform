#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
APPS_NAMESPACE="${APPS_NAMESPACE:-apps}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
APP_LABEL="${APP_LABEL:-app.kubernetes.io/name=demo-grpc}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-demo-grpc}"

LOCAL_DEMO_GRPC_PORT="${LOCAL_DEMO_GRPC_PORT:-19109}"
LOCAL_LOKI_PORT="${LOCAL_LOKI_PORT:-19110}"
LOCAL_TEMPO_PORT="${LOCAL_TEMPO_PORT:-19111}"

TRACE_ID=""
DEMO_PF_PID=""
LOKI_PF_PID=""
TEMPO_PF_PID=""

echo "============================================================"
echo "Check demo-grpc log/trace correlation"
echo "Context:              ${EXPECTED_CONTEXT}"
echo "Apps namespace:       ${APPS_NAMESPACE}"
echo "Observability ns:     ${OBS_NAMESPACE}"
echo "demo-grpc local port: ${LOCAL_DEMO_GRPC_PORT}"
echo "Loki local port:      ${LOCAL_LOKI_PORT}"
echo "Tempo local port:     ${LOCAL_TEMPO_PORT}"
echo "============================================================"
echo

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${EXPECTED_CONTEXT}" ]]; then
  echo "ERROR: kubectl context mismatch."
  echo "Current:  ${CURRENT_CONTEXT}"
  echo "Expected: ${EXPECTED_CONTEXT}"
  exit 1
fi

cleanup() {
  if [[ -n "${DEMO_PF_PID}" ]]; then
    kill "${DEMO_PF_PID}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${LOKI_PF_PID}" ]]; then
    kill "${LOKI_PF_PID}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${TEMPO_PF_PID}" ]]; then
    kill "${TEMPO_PF_PID}" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

wait_for_url() {
  local label="$1"
  local url="$2"
  local log_file="$3"

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
  echo "Port-forward log:"
  cat "${log_file}" || true
  exit 1
}

echo "ArgoCD application:"
kubectl -n argocd get application demo-grpc \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'
echo

echo "demo-grpc deployment image:"
kubectl -n "${APPS_NAMESPACE}" get deployment "${DEPLOYMENT_NAME}" \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
echo

echo "demo-grpc pods:"
kubectl -n "${APPS_NAMESPACE}" get pods -l "${APP_LABEL}"
echo

echo "Starting port-forwards..."
kubectl -n "${APPS_NAMESPACE}" port-forward svc/demo-grpc "${LOCAL_DEMO_GRPC_PORT}:50051" >/tmp/check-demo-grpc-correlation-demo.log 2>&1 &
DEMO_PF_PID=$!

kubectl -n "${OBS_NAMESPACE}" port-forward svc/loki "${LOCAL_LOKI_PORT}:3100" >/tmp/check-demo-grpc-correlation-loki.log 2>&1 &
LOKI_PF_PID=$!

kubectl -n "${OBS_NAMESPACE}" port-forward svc/tempo "${LOCAL_TEMPO_PORT}:3200" >/tmp/check-demo-grpc-correlation-tempo.log 2>&1 &
TEMPO_PF_PID=$!

sleep 3

wait_for_url "Loki readiness" "http://127.0.0.1:${LOCAL_LOKI_PORT}/ready" "/tmp/check-demo-grpc-correlation-loki.log"

if curl -fsS "http://127.0.0.1:${LOCAL_TEMPO_PORT}/ready" >/dev/null 2>&1; then
  echo "OK: Tempo readiness"
elif curl -fsS "http://127.0.0.1:${LOCAL_TEMPO_PORT}/-/ready" >/dev/null 2>&1; then
  echo "OK: Tempo readiness"
else
  echo "ERROR: Tempo did not become ready."
  cat /tmp/check-demo-grpc-correlation-tempo.log || true
  exit 1
fi

echo
echo "Generating gRPC healthcheck traffic..."
pushd services/demo-grpc >/dev/null

for i in {1..10}; do
  go run ./cmd/healthcheck -addr="127.0.0.1:${LOCAL_DEMO_GRPC_PORT}" >/dev/null
done

popd >/dev/null

echo "OK: gRPC healthcheck traffic generated."
echo

echo "Waiting for logs and traces ingestion..."
sleep 20

echo "Extracting recent trace_id from Kubernetes logs..."
TRACE_ID="$(
  kubectl -n "${APPS_NAMESPACE}" logs deployment/"${DEPLOYMENT_NAME}" --since=10m --tail=500 \
    | grep '"trace_id"' \
    | tail -1 \
    | sed -n 's/.*"trace_id":"\([^"]*\)".*/\1/p'
)"

if [[ -z "${TRACE_ID}" ]]; then
  echo "ERROR: Could not extract trace_id from demo-grpc logs."
  echo
  kubectl -n "${APPS_NAMESPACE}" logs deployment/"${DEPLOYMENT_NAME}" --since=10m --tail=100 || true
  exit 1
fi

echo "OK: extracted trace_id=${TRACE_ID}"
echo

echo "Checking Loki for trace_id..."
LOKI_RESPONSE="$(
  curl -G -fsS "http://127.0.0.1:${LOCAL_LOKI_PORT}/loki/api/v1/query_range" \
    --data-urlencode "query={namespace=\"${APPS_NAMESPACE}\"} |= \"${TRACE_ID}\"" \
    --data-urlencode "limit=5"
)"

RESPONSE="${LOKI_RESPONSE}" TRACE_ID="${TRACE_ID}" python - <<'PY'
import json
import os
import sys

trace_id = os.environ["TRACE_ID"]
data = json.loads(os.environ["RESPONSE"])

if data.get("status") != "success":
    print("ERROR: Loki query did not return success.")
    sys.exit(1)

streams = data.get("data", {}).get("result", [])
if not streams:
    print(f"ERROR: trace_id {trace_id} was not found in Loki.")
    sys.exit(1)

for stream in streams:
    for _, line in stream.get("values", []):
        if trace_id in line and "grpc request completed" in line:
            print("OK: trace_id found in Loki log stream.")
            print(line.strip())
            sys.exit(0)

print(f"ERROR: trace_id {trace_id} found in Loki response, but not in expected log line.")
sys.exit(1)
PY

echo
echo "Checking Tempo for trace_id..."
TEMPO_RESPONSE=""

for attempt in {1..24}; do
  if TEMPO_RESPONSE="$(
    curl -fsS "http://127.0.0.1:${LOCAL_TEMPO_PORT}/api/traces/${TRACE_ID}" 2>/tmp/check-demo-grpc-correlation-tempo-query.err
  )"; then
    echo "OK: Tempo returned trace_id=${TRACE_ID}."
    break
  fi

  echo "  attempt ${attempt}/24: trace_id not available in Tempo yet"
  sleep 5
done

if [[ -z "${TEMPO_RESPONSE}" ]]; then
  echo "ERROR: Tempo did not return trace_id=${TRACE_ID}."
  echo
  echo "Last Tempo query error:"
  cat /tmp/check-demo-grpc-correlation-tempo-query.err || true
  exit 1
fi

RESPONSE="${TEMPO_RESPONSE}" python - <<'PY'
import base64
import json
import os
import sys

data = json.loads(os.environ["RESPONSE"])

batches = data.get("batches", [])
if not batches:
    print("ERROR: Tempo trace response has no batches.")
    sys.exit(1)

service_ok = False
version = None
span_ok = False
status_ok = False

for batch in batches:
    for attr in batch.get("resource", {}).get("attributes", []):
        key = attr.get("key")
        value = attr.get("value", {})
        if key == "service.name" and value.get("stringValue") == "demo-grpc":
            service_ok = True
        if key == "service.version":
            version = value.get("stringValue")

    for scope_span in batch.get("scopeSpans", []):
        for span in scope_span.get("spans", []):
            if span.get("name") == "grpc.health.v1.Health/Check":
                span_ok = True

            for attr in span.get("attributes", []):
                if (
                    attr.get("key") == "rpc.response.status_code"
                    and attr.get("value", {}).get("stringValue") == "OK"
                ):
                    status_ok = True

if not service_ok:
    print("ERROR: Tempo trace does not contain service.name=demo-grpc.")
    sys.exit(1)

if not span_ok:
    print("ERROR: Tempo trace does not contain span grpc.health.v1.Health/Check.")
    sys.exit(1)

if not status_ok:
    print("ERROR: Tempo trace does not contain rpc.response.status_code=OK.")
    sys.exit(1)

print("OK: Tempo trace contains service.name=demo-grpc.")
if version:
    print(f"OK: Tempo trace contains service.version={version}.")
print("OK: Tempo trace contains grpc.health.v1.Health/Check span.")
print("OK: Tempo trace contains rpc.response.status_code=OK.")
PY

echo
echo "============================================================"
echo "Log/trace correlation validated successfully."
echo "trace_id=${TRACE_ID}"
echo "============================================================"
