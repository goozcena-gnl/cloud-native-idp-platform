#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
LOCAL_PROMETHEUS_PORT="${LOCAL_PROMETHEUS_PORT:-19096}"
LOCAL_ALERTMANAGER_PORT="${LOCAL_ALERTMANAGER_PORT:-19097}"

echo "============================================================"
echo "Check Alertmanager routing readiness"
echo "Context:                 ${EXPECTED_CONTEXT}"
echo "Namespace:               ${OBS_NAMESPACE}"
echo "Local Prometheus port:   ${LOCAL_PROMETHEUS_PORT}"
echo "Local Alertmanager port: ${LOCAL_ALERTMANAGER_PORT}"
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
kubectl -n argocd get application kube-prometheus-stack
echo

echo "Alertmanager CR:"
kubectl -n "${OBS_NAMESPACE}" get alertmanager kube-prometheus-stack-alertmanager
echo

echo "Alertmanager pods:"
kubectl -n "${OBS_NAMESPACE}" get pods | grep -i alertmanager
echo

echo "Alertmanager services:"
kubectl -n "${OBS_NAMESPACE}" get svc | grep -i alertmanager
echo

echo "Starting Prometheus port-forward..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/kube-prometheus-stack-prometheus "${LOCAL_PROMETHEUS_PORT}:9090" >/tmp/check-alertmanager-prometheus-port-forward.log 2>&1 &
PROM_PF_PID=$!

echo "Starting Alertmanager port-forward..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/kube-prometheus-stack-alertmanager "${LOCAL_ALERTMANAGER_PORT}:9093" >/tmp/check-alertmanager-ui-port-forward.log 2>&1 &
AM_PF_PID=$!

cleanup() {
  kill "${PROM_PF_PID}" >/dev/null 2>&1 || true
  kill "${AM_PF_PID}" >/dev/null 2>&1 || true
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
  echo "Prometheus port-forward log:"
  cat /tmp/check-alertmanager-prometheus-port-forward.log || true
  echo
  echo "Alertmanager port-forward log:"
  cat /tmp/check-alertmanager-ui-port-forward.log || true
  exit 1
}

wait_for_url "Prometheus readiness" "http://127.0.0.1:${LOCAL_PROMETHEUS_PORT}/-/ready"
wait_for_url "Alertmanager readiness" "http://127.0.0.1:${LOCAL_ALERTMANAGER_PORT}/-/ready"
echo

echo "Checking Prometheus Alertmanager discovery..."
ALERTMANAGERS_RESPONSE="$(curl -fsS "http://127.0.0.1:${LOCAL_PROMETHEUS_PORT}/api/v1/alertmanagers")"

if ! echo "${ALERTMANAGERS_RESPONSE}" | grep -q '"activeAlertmanagers":\['; then
  echo "ERROR: Prometheus Alertmanager discovery response is invalid."
  echo "${ALERTMANAGERS_RESPONSE}"
  exit 1
fi

if echo "${ALERTMANAGERS_RESPONSE}" | grep -q '"activeAlertmanagers":\[\]'; then
  echo "ERROR: Prometheus has no active Alertmanager."
  echo "${ALERTMANAGERS_RESPONSE}"
  exit 1
fi

echo "OK: Prometheus has an active Alertmanager."
echo

echo "Checking Alertmanager status API..."
ALERTMANAGER_STATUS="$(curl -fsS "http://127.0.0.1:${LOCAL_ALERTMANAGER_PORT}/api/v2/status")"

for expected in local-null platform-critical platform-warning gitops-alerts; do
  if ! echo "${ALERTMANAGER_STATUS}" | grep -q "${expected}"; then
    echo "ERROR: Alertmanager receiver not found in status config: ${expected}"
    echo "${ALERTMANAGER_STATUS}" | head -c 3000
    echo
    exit 1
  fi
  echo "OK: receiver ${expected}"
done

echo

echo "Checking Alertmanager alerts API..."
curl -fsS "http://127.0.0.1:${LOCAL_ALERTMANAGER_PORT}/api/v2/alerts" >/dev/null
echo "OK: Alertmanager alerts API reachable."
echo

echo "Checking platform alert rules still healthy..."
./scripts/check-platform-alerts.sh
echo

echo "============================================================"
echo "Alertmanager is enabled, reachable, and routing config is loaded."
echo "============================================================"
