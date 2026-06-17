#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-apps}"
SECRET_NAME="${SECRET_NAME:-ghcr-demo-grpc-pull}"
REGISTRY_SERVER="${REGISTRY_SERVER:-ghcr.io}"
GITHUB_USERNAME="${GITHUB_USERNAME:-}"

echo "============================================================"
echo "Configure GHCR image pull secret"
echo "Namespace: ${NAMESPACE}"
echo "Secret:    ${SECRET_NAME}"
echo "Registry:  ${REGISTRY_SERVER}"
echo "============================================================"
echo

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl is not installed or not in PATH."
  exit 1
fi

kubectl get namespace "${NAMESPACE}" >/dev/null

if [[ -z "${GITHUB_USERNAME}" ]]; then
  read -r -p "GitHub username: " GITHUB_USERNAME
fi

read -r -s -p "GitHub token with read:packages: " GHCR_TOKEN
echo

if [[ -z "${GHCR_TOKEN}" ]]; then
  echo "ERROR: token cannot be empty."
  exit 1
fi

kubectl -n "${NAMESPACE}" create secret docker-registry "${SECRET_NAME}" \
  --docker-server="${REGISTRY_SERVER}" \
  --docker-username="${GITHUB_USERNAME}" \
  --docker-password="${GHCR_TOKEN}" \
  --dry-run=client \
  -o yaml \
  | kubectl apply -f -

unset GHCR_TOKEN

echo
echo "Secret created/updated without printing credentials."
kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}"
