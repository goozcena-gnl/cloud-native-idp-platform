#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
RELEASE_NAME="${RELEASE_NAME:-argocd}"
CHART_REPO_NAME="${CHART_REPO_NAME:-argo}"
CHART_REPO_URL="${CHART_REPO_URL:-https://argoproj.github.io/argo-helm}"
CHART_NAME="${CHART_NAME:-argo/argo-cd}"
CHART_VERSION="${CHART_VERSION:-9.5.21}"
VALUES_PATH="${VALUES_PATH:-platform/helm-values/argocd-values.yaml}"

echo "============================================================"
echo "Installing ArgoCD (bootstrap)"
echo "Expected context: ${EXPECTED_CONTEXT}"
echo "Namespace:        ${ARGOCD_NAMESPACE}"
echo "Release:          ${RELEASE_NAME}"
echo "Chart:            ${CHART_NAME} (version ${CHART_VERSION})"
echo "Values:           ${VALUES_PATH}"
echo "============================================================"
echo

for tool in kubectl helm; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERROR: ${tool} is not installed or not in PATH."
    exit 1
  fi
done

if [[ ! -f "${VALUES_PATH}" ]]; then
  echo "ERROR: values file not found: ${VALUES_PATH}"
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

echo "Ensuring namespace '${ARGOCD_NAMESPACE}' exists..."
if ! kubectl get namespace "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: namespace '${ARGOCD_NAMESPACE}' not found."
  echo "Apply platform namespaces first:"
  echo "./scripts/apply-platform-namespaces.sh"
  exit 1
fi

echo "Adding/updating Helm repo '${CHART_REPO_NAME}'..."
helm repo add "${CHART_REPO_NAME}" "${CHART_REPO_URL}" >/dev/null 2>&1 || true
helm repo update "${CHART_REPO_NAME}" >/dev/null

echo
echo "Available ${CHART_NAME} chart versions:"
helm search repo "${CHART_NAME}" --versions | sed -n '1,6p' || true

echo
echo "Installing/upgrading ArgoCD release..."
helm upgrade --install "${RELEASE_NAME}" "${CHART_NAME}" \
  --namespace "${ARGOCD_NAMESPACE}" \
  --version "${CHART_VERSION}" \
  --values "${VALUES_PATH}" \
  --timeout 10m

echo
echo "Helm release status:"
helm status "${RELEASE_NAME}" --namespace "${ARGOCD_NAMESPACE}"

echo
echo "Waiting for ArgoCD workloads to be available..."
for workload in \
  deploy/"${RELEASE_NAME}"-applicationset-controller \
  deploy/"${RELEASE_NAME}"-redis \
  deploy/"${RELEASE_NAME}"-repo-server \
  deploy/"${RELEASE_NAME}"-server \
  statefulset/"${RELEASE_NAME}"-application-controller; do
  kubectl -n "${ARGOCD_NAMESPACE}" rollout status "${workload}" --timeout=300s
done

echo
echo "ArgoCD pods:"
kubectl -n "${ARGOCD_NAMESPACE}" get pods

echo
echo "ArgoCD services (expect ClusterIP only):"
kubectl -n "${ARGOCD_NAMESPACE}" get svc

echo
echo "============================================================"
echo "ArgoCD installed."
echo
echo "Next steps:"
echo "  1. Start local access:   ./scripts/argocd-port-forward.sh"
echo "  2. Get admin password:   see docs/GITOPS.md"
echo "============================================================"
