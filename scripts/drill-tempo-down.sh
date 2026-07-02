#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
APP_NAME="${APP_NAME:-tempo}"
WORKLOAD_KIND="${WORKLOAD_KIND:-statefulset}"
WORKLOAD_NAME="${WORKLOAD_NAME:-tempo}"
LOCAL_PROMETHEUS_PORT="${LOCAL_PROMETHEUS_PORT:-19103}"
LOCAL_ALERTMANAGER_PORT="${LOCAL_ALERTMANAGER_PORT:-19104}"
ALERT_NAME="${ALERT_NAME:-TempoDown}"

PROM_PF_PID=""
AM_PF_PID=""
ORIGINAL_REPLICAS=""

echo "============================================================"
echo "Reliability drill: ${ALERT_NAME}"
echo "Context:                 ${EXPECTED_CONTEXT}"
echo "Observability namespace: ${OBS_NAMESPACE}"
echo "Application:             ${APP_NAME}"
echo "Workload:                ${WORKLOAD_KIND}/${WORKLOAD_NAME}"
echo "Prometheus local port:   ${LOCAL_PROMETHEUS_PORT}"
echo "Alertmanager local port: ${LOCAL_ALERTMANAGER_PORT}"
echo "============================================================"
echo

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${EXPECTED_CONTEXT}" ]]; then
  echo "ERROR: kubectl context mismatch."
  echo "Current:  ${CURRENT_CONTEXT}"
  echo "Expected: ${EXPECTED_CONTEXT}"
  exit 1
fi

restore() {
  echo
  echo "============================================================"
  echo "Restoring drill state"
  echo "============================================================"

  if [[ -n "${ORIGINAL_REPLICAS}" ]]; then
    echo "Restoring ${WORKLOAD_KIND}/${WORKLOAD_NAME} replicas to ${ORIGINAL_REPLICAS}..."
    kubectl -n "${OBS_NAMESPACE}" scale "${WORKLOAD_KIND}/${WORKLOAD_NAME}" --replicas="${ORIGINAL_REPLICAS}" >/dev/null 2>&1 || true
  fi

  echo "Restoring ArgoCD automated sync for tempo and idp-root..."
  kubectl -n "${ARGOCD_NAMESPACE}" patch application "${APP_NAME}" \
    --type=merge \
    -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' >/dev/null 2>&1 || true

  kubectl -n "${ARGOCD_NAMESPACE}" patch application idp-root \
    --type=merge \
    -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' >/dev/null 2>&1 || true

  kubectl -n "${ARGOCD_NAMESPACE}" annotate application "${APP_NAME}" \
    argocd.argoproj.io/refresh=hard \
    --overwrite >/dev/null 2>&1 || true

  if [[ -n "${PROM_PF_PID}" ]]; then
    kill "${PROM_PF_PID}" >/dev/null 2>&1 || true
  fi

  if [[ -n "${AM_PF_PID}" ]]; then
    kill "${AM_PF_PID}" >/dev/null 2>&1 || true
  fi

  echo "Restore commands sent."
}

trap restore EXIT

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
  cat /tmp/drill-tempo-down-prometheus.log || true
  echo
  echo "Alertmanager port-forward log:"
  cat /tmp/drill-tempo-down-alertmanager.log || true
  exit 1
}

query_prometheus() {
  local query="$1"

  curl -G -fsS "http://127.0.0.1:${LOCAL_PROMETHEUS_PORT}/api/v1/query" \
    --data-urlencode "query=${query}"
}

prometheus_has_result() {
  local query="$1"
  local response

  response="$(query_prometheus "${query}")"

  RESPONSE="${response}" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["RESPONSE"])
result = data.get("data", {}).get("result", [])

sys.exit(0 if result else 1)
PY
}

wait_for_prometheus_alert_state() {
  local state="$1"
  local max_attempts="$2"

  echo "Waiting for Prometheus alert ${ALERT_NAME} state=${state}..."

  for attempt in $(seq 1 "${max_attempts}"); do
    if prometheus_has_result "ALERTS{alertname=\"${ALERT_NAME}\", alertstate=\"${state}\"}"; then
      echo "OK: ${ALERT_NAME} is ${state} in Prometheus."
      query_prometheus "ALERTS{alertname=\"${ALERT_NAME}\", alertstate=\"${state}\"}"
      echo
      return 0
    fi

    echo "  attempt ${attempt}/${max_attempts}: not ${state} yet"
    sleep 10
  done

  echo "ERROR: ${ALERT_NAME} did not reach state=${state}."
  echo "Current TempoDown expression:"
  query_prometheus '(max(up{namespace="observability", service="tempo"}) == 0) or absent(up{namespace="observability", service="tempo"})' || true
  echo
  echo "Current Tempo up:"
  query_prometheus 'up{namespace="observability", service="tempo"}' || true
  echo
  echo "Current ALERTS:"
  query_prometheus "ALERTS{alertname=\"${ALERT_NAME}\"}" || true
  echo
  exit 1
}

wait_for_alertmanager_alert() {
  local max_attempts="$1"

  echo "Waiting for Alertmanager to receive ${ALERT_NAME}..."

  for attempt in $(seq 1 "${max_attempts}"); do
    local response
    response="$(curl -fsS "http://127.0.0.1:${LOCAL_ALERTMANAGER_PORT}/api/v2/alerts")"

    if RESPONSE="${response}" ALERT_NAME="${ALERT_NAME}" python - <<'PY'
import json
import os
import sys

alert_name = os.environ["ALERT_NAME"]
alerts = json.loads(os.environ["RESPONSE"])

for alert in alerts:
    labels = alert.get("labels", {})
    status = alert.get("status", {})
    if labels.get("alertname") == alert_name and status.get("state") == "active":
        print(f"OK: Alertmanager has active alert {alert_name}.")
        sys.exit(0)

sys.exit(1)
PY
    then
      echo "${response}"
      echo
      return 0
    fi

    echo "  attempt ${attempt}/${max_attempts}: not active in Alertmanager yet"
    sleep 10
  done

  echo "ERROR: Alertmanager did not receive active ${ALERT_NAME}."
  curl -fsS "http://127.0.0.1:${LOCAL_ALERTMANAGER_PORT}/api/v2/alerts" || true
  echo
  exit 1
}

wait_for_alert_clear() {
  local max_attempts="$1"

  echo "Waiting for ${ALERT_NAME} to clear in Prometheus..."

  for attempt in $(seq 1 "${max_attempts}"); do
    if ! prometheus_has_result "ALERTS{alertname=\"${ALERT_NAME}\"}"; then
      echo "OK: ${ALERT_NAME} cleared from Prometheus."
      return 0
    fi

    echo "  attempt ${attempt}/${max_attempts}: alert still present"
    sleep 10
  done

  echo "WARNING: ${ALERT_NAME} did not clear within the wait window."
  query_prometheus "ALERTS{alertname=\"${ALERT_NAME}\"}" || true
  echo
}

echo "Initial ArgoCD applications:"
kubectl -n "${ARGOCD_NAMESPACE}" get applications "${APP_NAME}" idp-root platform-alerts kube-prometheus-stack \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'
echo

echo "Initial Tempo workload:"
kubectl -n "${OBS_NAMESPACE}" get "${WORKLOAD_KIND}" "${WORKLOAD_NAME}"
echo

echo "Initial Tempo pod/service:"
kubectl -n "${OBS_NAMESPACE}" get pod -l app.kubernetes.io/name=tempo || true
kubectl -n "${OBS_NAMESPACE}" get svc tempo
echo

ORIGINAL_REPLICAS="$(kubectl -n "${OBS_NAMESPACE}" get "${WORKLOAD_KIND}" "${WORKLOAD_NAME}" -o jsonpath='{.spec.replicas}')"
if [[ -z "${ORIGINAL_REPLICAS}" ]]; then
  ORIGINAL_REPLICAS="1"
fi

echo "Original replicas: ${ORIGINAL_REPLICAS}"
echo

echo "Temporarily disabling ArgoCD automated sync for idp-root and tempo..."
kubectl -n "${ARGOCD_NAMESPACE}" patch application idp-root \
  --type=json \
  -p='[{"op":"remove","path":"/spec/syncPolicy/automated"}]' >/dev/null 2>&1 || true

kubectl -n "${ARGOCD_NAMESPACE}" patch application "${APP_NAME}" \
  --type=json \
  -p='[{"op":"remove","path":"/spec/syncPolicy/automated"}]' >/dev/null 2>&1 || true

echo "Starting Prometheus port-forward..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/kube-prometheus-stack-prometheus "${LOCAL_PROMETHEUS_PORT}:9090" >/tmp/drill-tempo-down-prometheus.log 2>&1 &
PROM_PF_PID=$!

echo "Starting Alertmanager port-forward..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/kube-prometheus-stack-alertmanager "${LOCAL_ALERTMANAGER_PORT}:9093" >/tmp/drill-tempo-down-alertmanager.log 2>&1 &
AM_PF_PID=$!

wait_for_url "Prometheus readiness" "http://127.0.0.1:${LOCAL_PROMETHEUS_PORT}/-/ready"
wait_for_url "Alertmanager readiness" "http://127.0.0.1:${LOCAL_ALERTMANAGER_PORT}/-/ready"
echo

echo "Scaling ${WORKLOAD_KIND}/${WORKLOAD_NAME} to 0 replicas to simulate Tempo outage..."
kubectl -n "${OBS_NAMESPACE}" scale "${WORKLOAD_KIND}/${WORKLOAD_NAME}" --replicas=0
kubectl -n "${OBS_NAMESPACE}" get "${WORKLOAD_KIND}" "${WORKLOAD_NAME}"
echo

echo "Waiting for scrape/evaluation cycle..."
sleep 30

wait_for_prometheus_alert_state "pending" 24
wait_for_prometheus_alert_state "firing" 30
wait_for_alertmanager_alert 12

echo "============================================================"
echo "Incident detected successfully. Starting recovery."
echo "============================================================"

echo "Restoring ${WORKLOAD_KIND}/${WORKLOAD_NAME} replicas to ${ORIGINAL_REPLICAS}..."
kubectl -n "${OBS_NAMESPACE}" scale "${WORKLOAD_KIND}/${WORKLOAD_NAME}" --replicas="${ORIGINAL_REPLICAS}"
kubectl -n "${OBS_NAMESPACE}" rollout status "${WORKLOAD_KIND}/${WORKLOAD_NAME}"
echo

echo "Restoring ArgoCD automated sync..."
kubectl -n "${ARGOCD_NAMESPACE}" patch application "${APP_NAME}" \
  --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' >/dev/null

kubectl -n "${ARGOCD_NAMESPACE}" patch application idp-root \
  --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' >/dev/null

kubectl -n "${ARGOCD_NAMESPACE}" annotate application "${APP_NAME}" \
  argocd.argoproj.io/refresh=hard \
  --overwrite >/dev/null

sleep 60
wait_for_alert_clear 24

echo
echo "Final state:"
kubectl -n "${ARGOCD_NAMESPACE}" get applications "${APP_NAME}" idp-root platform-alerts kube-prometheus-stack \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'
echo
kubectl -n "${OBS_NAMESPACE}" get "${WORKLOAD_KIND}" "${WORKLOAD_NAME}"
echo
kubectl -n "${OBS_NAMESPACE}" get pod -l app.kubernetes.io/name=tempo || true
echo

echo "============================================================"
echo "Reliability drill ${ALERT_NAME} completed successfully."
echo "============================================================"
