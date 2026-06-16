#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
RELEASE_NAME="${RELEASE_NAME:-argocd}"
LOCAL_PORT="${LOCAL_PORT:-8081}"
REMOTE_PORT="${REMOTE_PORT:-80}"

echo "============================================================"
echo "ArgoCD local port-forward"
echo "Context:    ${EXPECTED_CONTEXT}"
echo "Namespace:  ${ARGOCD_NAMESPACE}"
echo "Local URL:  http://localhost:${LOCAL_PORT}"
echo "============================================================"
echo
echo "This exposes ArgoCD ONLY to your local machine via kubectl."
echo "Do not share this URL. Press Ctrl+C to stop."
echo

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl is not installed or not in PATH."
  exit 1
fi

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${EXPECTED_CONTEXT}" ]]; then
  echo "ERROR: kubectl context mismatch."
  echo "Current context:  ${CURRENT_CONTEXT}"
  echo "Expected context: ${EXPECTED_CONTEXT}"
  echo
  echo "Fix with:"
  echo "kubectl config use-context ${EXPECTED_CONTEXT}"
  exit 1
fi

echo "Forwarding localhost:${LOCAL_PORT} -> svc/${RELEASE_NAME}-server:${REMOTE_PORT}"
exec kubectl -n "${ARGOCD_NAMESPACE}" port-forward \
  "svc/${RELEASE_NAME}-server" "${LOCAL_PORT}:${REMOTE_PORT}"
