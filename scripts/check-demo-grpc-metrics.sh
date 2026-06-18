#!/usr/bin/env bash
set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
APP_NAMESPACE="${APP_NAMESPACE:-apps}"
OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"
APP_NAME="${APP_NAME:-demo-grpc}"
LOCAL_METRICS_PORT="${LOCAL_METRICS_PORT:-9092}"
LOCAL_PROM_PORT="${LOCAL_PROM_PORT:-9099}"

echo "============================================================"
echo "Check demo-grpc Prometheus metrics"
echo "Context:        ${EXPECTED_CONTEXT}"
echo "App namespace:  ${APP_NAMESPACE}"
echo "Obs namespace:  ${OBS_NAMESPACE}"
echo "App:            ${APP_NAME}"
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
kubectl -n argocd get application "${APP_NAME}" kube-prometheus-stack

echo
echo "Service ports:"
kubectl -n "${APP_NAMESPACE}" get svc "${APP_NAME}" -o wide
kubectl -n "${APP_NAMESPACE}" get svc "${APP_NAME}" \
  -o jsonpath='{range .spec.ports[*]}{.name}{" port="}{.port}{" targetPort="}{.targetPort}{"\n"}{end}'

echo
echo "ServiceMonitor:"
kubectl -n "${APP_NAMESPACE}" get servicemonitor "${APP_NAME}" -o wide

echo
echo "Pods:"
kubectl -n "${APP_NAMESPACE}" get pods -l "app.kubernetes.io/instance=${APP_NAME}" -o wide

echo
echo "Testing /metrics through Kubernetes Service port-forward..."
kubectl -n "${APP_NAMESPACE}" port-forward "svc/${APP_NAME}" \
  "${LOCAL_METRICS_PORT}:9090" >/tmp/demo-grpc-metrics-port-forward.log 2>&1 &
METRICS_PF_PID=$!

cleanup() {
  kill "${METRICS_PF_PID}" >/dev/null 2>&1 || true
  kill "${PROM_PF_PID:-}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 3
curl -fsS "http://localhost:${LOCAL_METRICS_PORT}/metrics" \
  | grep -E "go_goroutines|process_cpu_seconds_total" >/dev/null
echo "Service /metrics endpoint OK."

echo
echo "Testing Prometheus target discovery..."
kubectl -n "${OBS_NAMESPACE}" port-forward svc/kube-prometheus-stack-prometheus \
  "${LOCAL_PROM_PORT}:9090" >/tmp/prometheus-port-forward.log 2>&1 &
PROM_PF_PID=$!
sleep 5

echo "Looking for demo-grpc in Prometheus targets..."
curl -fsS "http://localhost:${LOCAL_PROM_PORT}/api/v1/targets" \
  | grep -q "${APP_NAME}"
echo "Prometheus target discovery OK."

echo
echo "Querying Prometheus up metric for apps namespace..."
curl -fsS "http://localhost:${LOCAL_PROM_PORT}/api/v1/query?query=up%7Bnamespace%3D%22${APP_NAMESPACE}%22%7D" \
  | grep -q "${APP_NAME}"
echo "Prometheus scrape query OK."

echo
echo "============================================================"
echo "demo-grpc metrics are exposed and discovered by Prometheus."
echo "============================================================"
