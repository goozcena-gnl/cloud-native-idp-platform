#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
APP_NAMESPACE="${APP_NAMESPACE:-apps}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
APP_NAME="${APP_NAME:-demo-grpc}"
LOCAL_GRPC_PORT="${LOCAL_GRPC_PORT:-50052}"
LOCAL_TEMPO_PORT="${LOCAL_TEMPO_PORT:-19098}"
TRACE_CALLS="${TRACE_CALLS:-10}"

echo "============================================================"
echo "Check demo-grpc OpenTelemetry traces"
echo "Context:          ${EXPECTED_CONTEXT}"
echo "App namespace:    ${APP_NAMESPACE}"
echo "Obs namespace:    ${OBS_NAMESPACE}"
echo "App:              ${APP_NAME}"
echo "Local gRPC port:  ${LOCAL_GRPC_PORT}"
echo "Local Tempo port: ${LOCAL_TEMPO_PORT}"
echo "Trace calls:      ${TRACE_CALLS}"
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
kubectl -n argocd get applications demo-grpc tempo \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'
echo

echo "Checking demo-grpc rollout..."
kubectl -n "${APP_NAMESPACE}" rollout status "deploy/${APP_NAME}"
echo

echo "Checking tracing environment variables..."
kubectl -n "${APP_NAMESPACE}" get deploy "${APP_NAME}" \
  -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' \
  | tee /tmp/check-demo-grpc-traces-env.txt

grep -q '^OTEL_TRACES_ENABLED=true$' /tmp/check-demo-grpc-traces-env.txt
grep -q '^OTEL_EXPORTER_OTLP_ENDPOINT=tempo.observability.svc.cluster.local:4317$' /tmp/check-demo-grpc-traces-env.txt
echo "OK: tracing environment variables are configured."
echo

echo "Checking Tempo readiness through Service..."
kubectl -n "${OBS_NAMESPACE}" run tempo-trace-check \
  --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 \
  -- curl -fsS "http://tempo.${OBS_NAMESPACE}.svc.cluster.local:3200/ready"
echo
echo "OK: Tempo is reachable from the cluster."
echo

echo "Starting demo-grpc port-forward..."
kubectl -n "${APP_NAMESPACE}" port-forward "svc/${APP_NAME}" "${LOCAL_GRPC_PORT}:50051" >/tmp/check-demo-grpc-traces-grpc-port-forward.log 2>&1 &
GRPC_PF_PID=$!

echo "Starting Tempo port-forward..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/tempo "${LOCAL_TEMPO_PORT}:3200" >/tmp/check-demo-grpc-traces-tempo-port-forward.log 2>&1 &
TEMPO_PF_PID=$!

cleanup() {
  kill "${GRPC_PF_PID}" >/dev/null 2>&1 || true
  kill "${TEMPO_PF_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 3

echo "Generating gRPC traffic..."
for i in $(seq 1 "${TRACE_CALLS}"); do
  echo "  gRPC health call ${i}/${TRACE_CALLS}"
  (
    cd services/demo-grpc
    go run ./cmd/healthcheck -addr "localhost:${LOCAL_GRPC_PORT}" >/dev/null
  )
done
echo "OK: gRPC traffic generated."
echo

echo "Waiting for OpenTelemetry batch exporter..."
sleep 20

echo "Checking Tempo tag values..."
SERVICE_VALUES="$(curl -fsS "http://127.0.0.1:${LOCAL_TEMPO_PORT}/api/search/tag/service.name/values")"
echo "${SERVICE_VALUES}"
echo "${SERVICE_VALUES}" | grep -q '"demo-grpc"'
echo "OK: Tempo contains service.name=demo-grpc."
echo

echo "Searching demo-grpc traces in Tempo..."
TRACE_SEARCH_RESPONSE="$(curl -G -fsS "http://127.0.0.1:${LOCAL_TEMPO_PORT}/api/search" \
  --data-urlencode 'tags=service.name=demo-grpc' \
  --data-urlencode 'limit=20')"

echo "${TRACE_SEARCH_RESPONSE}"
echo "${TRACE_SEARCH_RESPONSE}" | grep -q '"rootServiceName":"demo-grpc"'
echo "${TRACE_SEARCH_RESPONSE}" | grep -q 'grpc.health.v1.Health/Check'
echo "OK: demo-grpc traces are present in Tempo."
echo

echo "============================================================"
echo "demo-grpc traces are exported to Tempo and searchable."
echo "============================================================"
