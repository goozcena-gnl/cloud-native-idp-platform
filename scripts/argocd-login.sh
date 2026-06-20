#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_SERVER="${ARGOCD_SERVER:-localhost:8081}"
ADMIN_USER="${ADMIN_USER:-admin}"
INITIAL_SECRET="${INITIAL_SECRET:-argocd-initial-admin-secret}"

echo "============================================================"
echo "ArgoCD local login helper"
echo "Context:    ${EXPECTED_CONTEXT}"
echo "Namespace:  ${ARGOCD_NAMESPACE}"
echo "Server:     ${ARGOCD_SERVER}"
echo "============================================================"
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

echo "kubectl context is correct: ${CURRENT_CONTEXT}"
echo

# Retrieve the initial admin password.
if ! kubectl -n "${ARGOCD_NAMESPACE}" get secret "${INITIAL_SECRET}" >/dev/null 2>&1; then
  echo "ERROR: Secret '${INITIAL_SECRET}' not found in namespace '${ARGOCD_NAMESPACE}'."
  echo
  echo "This secret is created on first install and may have been deleted."
  echo "Reset the admin password and regenerate it with:"
  echo
  echo "  kubectl -n ${ARGOCD_NAMESPACE} patch secret argocd-secret \\"
  echo "    -p '{\"data\": {\"admin.password\": null, \"admin.passwordMtime\": null}}'"
  echo "  kubectl -n ${ARGOCD_NAMESPACE} rollout restart deploy argocd-server"
  echo
  echo "Then re-run this script."
  exit 1
fi

ADMIN_PASSWORD="$(kubectl -n "${ARGOCD_NAMESPACE}" get secret "${INITIAL_SECRET}" \
  -o jsonpath='{.data.password}' | base64 -d)"

if [[ -z "${ADMIN_PASSWORD}" ]]; then
  echo "ERROR: Retrieved admin password is empty."
  exit 1
fi

echo "Admin username: ${ADMIN_USER}"
echo "Admin password: ${ADMIN_PASSWORD}"
echo

# If the argocd CLI is available, log in automatically.
if command -v argocd >/dev/null 2>&1; then
  echo "Logging in via argocd CLI against ${ARGOCD_SERVER} ..."
  echo "(Ensure ./scripts/argocd-port-forward.sh is running in another terminal.)"
  echo
  if argocd login "${ARGOCD_SERVER}" \
    --username "${ADMIN_USER}" \
    --password "${ADMIN_PASSWORD}" \
    --plaintext; then
    echo
    echo "Logged in. Try: argocd app list"
  else
    echo
    echo "ERROR: argocd login failed."
    echo "Is the port-forward running? Start it with:"
    echo "  ./scripts/argocd-port-forward.sh"
    exit 1
  fi
else
  echo "argocd CLI not found in PATH."
  echo "Log in through the UI instead:"
  echo
  echo "  1. Start the port-forward: ./scripts/argocd-port-forward.sh"
  echo "  2. Open: http://${ARGOCD_SERVER}"
  echo "  3. Username: ${ADMIN_USER}"
  echo "  4. Password: (shown above)"
fi

echo "============================================================"
