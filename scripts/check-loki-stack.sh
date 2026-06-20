#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
LOCAL_LOKI_PORT="${LOCAL_LOKI_PORT:-3101}"

echo "============================================================"
echo "Check Loki + Alloy logs stack"
echo "Context:        ${EXPECTED_CONTEXT}"
echo "Obs namespace:  ${OBS_NAMESPACE}"
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
kubectl -n argocd get application loki alloy-logs grafana-dashboards
echo

echo "Pods:"
kubectl -n "${OBS_NAMESPACE}" get pods -o wide
echo

echo "Services:"
kubectl -n "${OBS_NAMESPACE}" get svc loki alloy-logs
echo

echo "Grafana Loki datasource ConfigMap:"
kubectl -n "${OBS_NAMESPACE}" get configmap loki-datasource -o wide
echo

echo "Waiting for Loki StatefulSet..."
kubectl -n "${OBS_NAMESPACE}" rollout status statefulset/loki --timeout=300s
echo

echo "Waiting for Alloy deployment..."
kubectl -n "${OBS_NAMESPACE}" rollout status deployment/alloy-logs --timeout=300s
echo

echo "Testing Loki /ready endpoint..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/loki "${LOCAL_LOKI_PORT}:3100" >/tmp/loki-ready-port-forward.log 2>&1 &
LOKI_PF_PID=$!

cleanup() {
  kill "${LOKI_PF_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 3

curl -fsS "http://localhost:${LOCAL_LOKI_PORT}/ready" | grep -q "ready"

echo "Loki ready endpoint OK."
echo

echo "============================================================"
echo "Loki + Alloy logs stack is healthy."
echo "============================================================"
