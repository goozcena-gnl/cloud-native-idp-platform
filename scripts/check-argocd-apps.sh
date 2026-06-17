#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
PROJECT_NAME="${PROJECT_NAME:-idp-platform}"

echo "============================================================"
echo "Check ArgoCD GitOps Applications"
echo "Expected context: ${EXPECTED_CONTEXT}"
echo "Namespace:        ${ARGOCD_NAMESPACE}"
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
  echo "  kubectl config use-context ${EXPECTED_CONTEXT}"
  exit 1
fi

echo "kubectl context is correct: ${CURRENT_CONTEXT}"
echo

kubectl get namespace "${ARGOCD_NAMESPACE}" >/dev/null

echo "AppProject:"
if kubectl -n "${ARGOCD_NAMESPACE}" get appproject "${PROJECT_NAME}" >/dev/null 2>&1; then
  kubectl -n "${ARGOCD_NAMESPACE}" get appproject "${PROJECT_NAME}" -o wide
else
  echo "${PROJECT_NAME}: not found yet"
fi
echo

echo "All Applications (${ARGOCD_NAMESPACE}):"
kubectl -n "${ARGOCD_NAMESPACE}" get applications \
  -o custom-columns='NAME:.metadata.name,PROJECT:.spec.project,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision'
echo

echo "Application sources:"
mapfile -t APPS < <(kubectl -n "${ARGOCD_NAMESPACE}" get applications -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')
for app in "${APPS[@]}"; do
  kubectl -n "${ARGOCD_NAMESPACE}" get application "${app}" \
    -o jsonpath='Name: {.metadata.name}{"\n"}Repo: {.spec.source.repoURL}{"\n"}Revision: {.spec.source.targetRevision}{"\n"}Path: {.spec.source.path}{"\n"}Automated prune: {.spec.syncPolicy.automated.prune}{"\n"}Automated selfHeal: {.spec.syncPolicy.automated.selfHeal}{"\n\n"}'
done

echo "Managed namespaces:"
kubectl get namespaces argocd platform-system apps observability security --show-labels

echo
echo "============================================================"
echo "Troubleshooting commands:"
echo "  kubectl -n ${ARGOCD_NAMESPACE} describe application <name>"
echo "  kubectl -n ${ARGOCD_NAMESPACE} get events --sort-by=.lastTimestamp"
echo "  kubectl -n ${ARGOCD_NAMESPACE} logs deploy/argocd-repo-server"
echo "  kubectl -n ${ARGOCD_NAMESPACE} logs statefulset/argocd-application-controller"
echo "  ./scripts/check-argocd-repo-secret.sh"
echo "============================================================"