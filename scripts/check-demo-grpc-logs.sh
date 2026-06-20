#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
APP_NAMESPACE="${APP_NAMESPACE:-apps}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
APP_CONTAINER="${APP_CONTAINER:-demo-grpc}"
LOCAL_LOKI_PORT="${LOCAL_LOKI_PORT:-3102}"

echo "============================================================"
echo "Check demo-grpc logs in Loki"
echo "Context:        ${EXPECTED_CONTEXT}"
echo "App namespace:  ${APP_NAMESPACE}"
echo "Obs namespace:  ${OBS_NAMESPACE}"
echo "Container:      ${APP_CONTAINER}"
echo "Local Loki port:${LOCAL_LOKI_PORT}"
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
kubectl -n argocd get application loki alloy-logs demo-grpc
echo

echo "demo-grpc pod:"
kubectl -n "${APP_NAMESPACE}" get pods -l app.kubernetes.io/instance=demo-grpc -o wide
echo

echo "Recent Kubernetes logs:"
kubectl -n "${APP_NAMESPACE}" logs deployment/demo-grpc --tail=20
echo

echo "Starting Loki port-forward..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/loki "${LOCAL_LOKI_PORT}:3100" >/tmp/demo-grpc-loki-port-forward.log 2>&1 &
LOKI_PF_PID=$!

cleanup() {
  kill "${LOKI_PF_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 3

echo "Checking Loki readiness..."
curl -fsS "http://localhost:${LOCAL_LOKI_PORT}/ready" | grep -q "ready"
echo "Loki ready endpoint OK."
echo

QUERY_WINDOW_HOURS="${QUERY_WINDOW_HOURS:-24}"

echo "Loki query window: last ${QUERY_WINDOW_HOURS}h"

START="$(($(date -u -d "${QUERY_WINDOW_HOURS} hours ago" +%s) * 1000000000))"
END="$(($(date -u +%s) * 1000000000))"

echo "Querying Loki for demo-grpc logs..."
RESPONSE="$(
  curl -G -s "http://localhost:${LOCAL_LOKI_PORT}/loki/api/v1/query_range" \
    --data-urlencode "query={namespace=\"${APP_NAMESPACE}\", container=\"${APP_CONTAINER}\"}" \
    --data-urlencode "start=${START}" \
    --data-urlencode "end=${END}" \
    --data-urlencode "limit=50"
)"

if ! echo "${RESPONSE}" | grep -q '"status":"success"'; then
  echo "ERROR: Loki query did not return success."
  echo "${RESPONSE}" | head -c 2000
  echo
  exit 1
fi

if ! echo "${RESPONSE}" | grep -q "${APP_CONTAINER}"; then
  echo "ERROR: Loki response does not contain ${APP_CONTAINER} logs."
  echo "${RESPONSE}" | head -c 2000
  echo
  exit 1
fi

if ! echo "${RESPONSE}" | grep -q "starting service"; then
  echo "ERROR: Loki response does not contain the expected startup service log."
  echo "${RESPONSE}" | head -c 2000
  echo
  exit 1
fi

if ! echo "${RESPONSE}" | grep -q "starting metrics server"; then
  echo "ERROR: Loki response does not contain the expected startup metrics log."
  echo "${RESPONSE}" | head -c 2000
  echo
  exit 1
fi

if ! echo "${RESPONSE}" | grep -q "sha-"; then
  echo "ERROR: Loki response does not contain the immutable sha-* application version."
  echo "${RESPONSE}" | head -c 2000
  echo
  exit 1
fi

echo "demo-grpc logs found in Loki."
echo "Structured JSON startup logs found in Loki."
echo

echo "Sample Loki response:"
echo "${RESPONSE}" | head -c 1200
echo
echo

echo "============================================================"
echo "demo-grpc structured JSON logs are collected by Alloy and queryable in Loki."
echo "============================================================"