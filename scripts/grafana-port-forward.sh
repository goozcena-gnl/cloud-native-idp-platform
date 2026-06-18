#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
NAMESPACE="${NAMESPACE:-observability}"
LOCAL_PORT="${LOCAL_PORT:-3000}"

echo "============================================================"
echo "Grafana port-forward"
echo "Context: ${EXPECTED_CONTEXT}"
echo "URL:     http://localhost:${LOCAL_PORT}"
echo "============================================================"
echo

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl is not installed or not in PATH."
  exit 1
fi

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${EXPECTED_CONTEXT}" ]]; then
  echo "ERROR: kubectl context mismatch."
  echo "Current:  ${CURRENT_CONTEXT}"
  echo "Expected: ${EXPECTED_CONTEXT}"
  exit 1
fi

echo "Open: http://localhost:${LOCAL_PORT}"
echo "Username: admin"
echo "Password: admin"
echo
echo "Stop with CTRL+C."
echo

kubectl -n "${NAMESPACE}" port-forward svc/kube-prometheus-stack-grafana "${LOCAL_PORT}:80"
