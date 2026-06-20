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

PASSWORD_SOURCE="environment"

if [[ -z "${ARGOCD_PASSWORD:-}" ]]; then
  if kubectl -n "${ARGOCD_NAMESPACE}" get secret "${INITIAL_SECRET}" >/dev/null 2>&1; then
    ARGOCD_PASSWORD="$(
      kubectl -n "${ARGOCD_NAMESPACE}" get secret "${INITIAL_SECRET}" \
        -o jsonpath='{.data.password}' | base64 -d
    )"
    PASSWORD_SOURCE="initial admin Secret"
  else
    PASSWORD_SOURCE="interactive prompt"
    read -rsp "ArgoCD admin password: " ARGOCD_PASSWORD
    echo
  fi
fi

if [[ -z "${ARGOCD_PASSWORD}" ]]; then
  echo "ERROR: ArgoCD password is empty."
  exit 1
fi

echo "Admin username: ${ADMIN_USER}"
echo "Password source: ${PASSWORD_SOURCE}"
echo

if command -v argocd >/dev/null 2>&1; then
  echo "Logging in via argocd CLI against ${ARGOCD_SERVER} ..."
  echo "(Ensure ./scripts/argocd-port-forward.sh is running in another terminal.)"
  echo

  if argocd login "${ARGOCD_SERVER}" \
    --username "${ADMIN_USER}" \
    --password "${ARGOCD_PASSWORD}" \
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
  echo "Start the port-forward and log in through the UI:"
  echo
  echo "  ./scripts/argocd-port-forward.sh"
  echo "  http://${ARGOCD_SERVER}"
  echo
  echo "Use username '${ADMIN_USER}' and your current local admin password."
fi

echo "============================================================"