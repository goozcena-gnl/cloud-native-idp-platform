#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
NAMESPACE="${NAMESPACE:-apps}"
APP_NAME="${APP_NAME:-demo-grpc}"
LOCAL_PORT="${LOCAL_PORT:-50053}"
SERVICE_PORT="${SERVICE_PORT:-50051}"
SERVICE_DIR="${SERVICE_DIR:-services/demo-grpc}"

echo "============================================================"
echo "Check demo-grpc Kubernetes deployment"
echo "Context:   ${EXPECTED_CONTEXT}"
echo "Namespace: ${NAMESPACE}"
echo "App:       ${APP_NAME}"
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
kubectl -n argocd get application "${APP_NAME}"

echo
echo "Kubernetes resources:"
kubectl -n "${NAMESPACE}" get deploy,svc,pods -l app.kubernetes.io/instance="${APP_NAME}" -o wide

echo
echo "Waiting for deployment rollout..."
kubectl -n "${NAMESPACE}" rollout status deployment/"${APP_NAME}" --timeout=180s

echo
echo "Pod details:"
kubectl -n "${NAMESPACE}" get pods -l app.kubernetes.io/instance="${APP_NAME}" -o wide

POD_NAME="$(kubectl -n "${NAMESPACE}" get pods -l app.kubernetes.io/instance="${APP_NAME}" -o jsonpath='{.items[0].metadata.name}')"

echo
echo "Container security context:"
kubectl -n "${NAMESPACE}" get pod "${POD_NAME}" -o jsonpath='{.spec.securityContext}{"\n"}{.spec.containers[0].securityContext}{"\n"}'

echo
echo "Starting port-forward for healthcheck..."
kubectl -n "${NAMESPACE}" port-forward svc/"${APP_NAME}" "${LOCAL_PORT}:${SERVICE_PORT}" >/tmp/demo-grpc-k8s-port-forward.log 2>&1 &
PF_PID=$!

cleanup() {
  kill "${PF_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 3

echo
echo "Running gRPC healthcheck through Kubernetes Service..."
(
  cd "${SERVICE_DIR}"
  go run ./cmd/healthcheck -addr "localhost:${LOCAL_PORT}"
)

echo
echo "Application logs:"
kubectl -n "${NAMESPACE}" logs deployment/"${APP_NAME}" --tail=30

echo
echo "============================================================"
echo "demo-grpc Kubernetes deployment is healthy."
echo "============================================================"
