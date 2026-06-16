#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
SECRET_NAME="${ARGOCD_REPO_SECRET_NAME:-argocd-repo-cloud-native-idp-platform}"
REPO_URL="${ARGOCD_REPO_URL:-https://github.com/goozdu12/cloud-native-idp-platform.git}"
GITHUB_USERNAME="${GITHUB_USERNAME:-}"

echo "============================================================"
echo "Configure ArgoCD private Git repository access"
echo "Expected context: ${EXPECTED_CONTEXT}"
echo "Namespace:        ${NAMESPACE}"
echo "Secret name:      ${SECRET_NAME}"
echo "Repo URL:         ${REPO_URL}"
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

kubectl get namespace "${NAMESPACE}" >/dev/null

if [[ -z "${GITHUB_USERNAME}" ]]; then
  read -r -p "GitHub username: " GITHUB_USERNAME
fi

if [[ -z "${GITHUB_USERNAME}" ]]; then
  echo "ERROR: GitHub username cannot be empty."
  exit 1
fi

echo
echo "Paste a GitHub fine-grained PAT with read-only Contents access."
echo "The token will not be printed."
read -r -s -p "GitHub token: " GITHUB_TOKEN
echo
echo

if [[ -z "${GITHUB_TOKEN}" ]]; then
  echo "ERROR: GitHub token cannot be empty."
  exit 1
fi

echo "Creating/updating ArgoCD repository Secret..."
kubectl -n "${NAMESPACE}" create secret generic "${SECRET_NAME}" \
  --from-literal=type=git \
  --from-literal=url="${REPO_URL}" \
  --from-literal=username="${GITHUB_USERNAME}" \
  --from-literal=password="${GITHUB_TOKEN}" \
  --dry-run=client \
  -o yaml \
  | kubectl label -f - argocd.argoproj.io/secret-type=repository --local -o yaml \
  | kubectl apply -f -

unset GITHUB_TOKEN

echo
echo "Validating Secret metadata without printing credentials..."
kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}" \
  -o jsonpath='Name: {.metadata.name}{"\n"}Type: {.type}{"\n"}ArgoCD secret type: {.metadata.labels.argocd\.argoproj\.io/secret-type}{"\n"}'
echo

echo
echo "============================================================"
echo "ArgoCD private repository credential configured."
echo "No token was written to the repository."
echo "============================================================"
