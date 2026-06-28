#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
LOCAL_TEMPO_PORT="${LOCAL_TEMPO_PORT:-19098}"
LOCAL_PROMETHEUS_PORT="${LOCAL_PROMETHEUS_PORT:-19099}"
LOCAL_GRAFANA_PORT="${LOCAL_GRAFANA_PORT:-3010}"

echo "============================================================"
echo "Check Tempo tracing stack"
echo "Context:              ${EXPECTED_CONTEXT}"
echo "Namespace:            ${OBS_NAMESPACE}"
echo "Local Tempo port:     ${LOCAL_TEMPO_PORT}"
echo "Local Prometheus port:${LOCAL_PROMETHEUS_PORT}"
echo "Local Grafana port:   ${LOCAL_GRAFANA_PORT}"
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
kubectl -n argocd get application tempo
echo

echo "Tempo pods:"
kubectl -n "${OBS_NAMESPACE}" get pods | grep -i tempo
echo

echo "Tempo services:"
kubectl -n "${OBS_NAMESPACE}" get svc | grep -i tempo
echo

echo "Tempo datasource ConfigMap:"
kubectl -n "${OBS_NAMESPACE}" get configmap tempo-datasource
echo

TEMPO_SERVICE="$(kubectl -n "${OBS_NAMESPACE}" get svc -o name | grep -E '^service/tempo$' | head -1 | sed 's#service/##')"

if [[ -z "${TEMPO_SERVICE}" ]]; then
  echo "ERROR: service/tempo not found."
  kubectl -n "${OBS_NAMESPACE}" get svc
  exit 1
fi

echo "Starting Tempo port-forward..."
kubectl -n "${OBS_NAMESPACE}" port-forward "svc/${TEMPO_SERVICE}" "${LOCAL_TEMPO_PORT}:3200" >/tmp/check-tempo-port-forward.log 2>&1 &
TEMPO_PF_PID=$!

echo "Starting Prometheus port-forward..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/kube-prometheus-stack-prometheus "${LOCAL_PROMETHEUS_PORT}:9090" >/tmp/check-tempo-prometheus-port-forward.log 2>&1 &
PROM_PF_PID=$!

echo "Starting Grafana port-forward..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/kube-prometheus-stack-grafana "${LOCAL_GRAFANA_PORT}:80" >/tmp/check-tempo-grafana-port-forward.log 2>&1 &
GRAFANA_PF_PID=$!

cleanup() {
  kill "${TEMPO_PF_PID}" >/dev/null 2>&1 || true
  kill "${PROM_PF_PID}" >/dev/null 2>&1 || true
  kill "${GRAFANA_PF_PID}" >/dev/null 2>&1 || true
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
  echo "Tempo port-forward log:"
  cat /tmp/check-tempo-port-forward.log || true
  echo
  echo "Prometheus port-forward log:"
  cat /tmp/check-tempo-prometheus-port-forward.log || true
  echo
  echo "Grafana port-forward log:"
  cat /tmp/check-tempo-grafana-port-forward.log || true
  exit 1
}

wait_for_url "Tempo readiness" "http://127.0.0.1:${LOCAL_TEMPO_PORT}/ready"
wait_for_url "Prometheus readiness" "http://127.0.0.1:${LOCAL_PROMETHEUS_PORT}/-/ready"
wait_for_url "Grafana health" "http://127.0.0.1:${LOCAL_GRAFANA_PORT}/api/health"
echo

echo "Checking Tempo metrics endpoint..."
curl -fsS "http://127.0.0.1:${LOCAL_TEMPO_PORT}/metrics" | grep -q "tempo_"
echo "OK: Tempo metrics endpoint exposes tempo_* metrics."
echo

echo "Checking Tempo datasource in Grafana..."
GRAFANA_DATASOURCE_RESPONSE="$(curl -fsS -u admin:admin "http://127.0.0.1:${LOCAL_GRAFANA_PORT}/api/datasources/uid/tempo")"

echo "${GRAFANA_DATASOURCE_RESPONSE}" | grep -q '"uid":"tempo"'
echo "${GRAFANA_DATASOURCE_RESPONSE}" | grep -q '"type":"tempo"'
echo "OK: Tempo datasource is provisioned in Grafana."
echo

echo "Checking Tempo target in Prometheus, if ServiceMonitor is active..."
PROM_RESPONSE="$(curl -G -s "http://127.0.0.1:${LOCAL_PROMETHEUS_PORT}/api/v1/query" \
  --data-urlencode 'query=up{namespace="observability", service=~".*tempo.*"}')"

echo "${PROM_RESPONSE}"

echo
echo "============================================================"
echo "Tempo stack is deployed, reachable, and provisioned in Grafana."
echo "============================================================"
