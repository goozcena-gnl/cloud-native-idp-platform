#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
MANIFEST_PATH="${MANIFEST_PATH:-platform/namespaces/namespaces.yaml}"

echo "============================================================"
echo "Applying platform namespaces"
echo "Expected kubectl context: ${EXPECTED_CONTEXT}"
echo "Manifest path:             ${MANIFEST_PATH}"
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

echo "Applying namespace manifest..."
kubectl apply -f "${MANIFEST_PATH}"

echo
echo "Validating namespaces..."
kubectl get namespaces \
  argocd \
  platform-system \
  apps \
  observability \
  security \
  --show-labels

echo
echo "============================================================"
echo "Platform namespaces are ready."
echo "============================================================"
