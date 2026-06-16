#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
PROJECT_NAME="${PROJECT_NAME:-idp-platform}"
ROOT_APP_NAME="${ROOT_APP_NAME:-idp-root}"
CHILD_APP_NAME="${CHILD_APP_NAME:-platform-namespaces}"

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
  echo "kubectl config use-context ${EXPECTED_CONTEXT}"
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

echo "Applications:"
for app in "${ROOT_APP_NAME}" "${CHILD_APP_NAME}"; do
  if kubectl -n "${ARGOCD_NAMESPACE}" get application "${app}" >/dev/null 2>&1; then
    kubectl -n "${ARGOCD_NAMESPACE}" get application "${app}" \
      -o custom-columns='NAME:.metadata.name,PROJECT:.spec.project,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision'
  else
    echo "${app}: not found yet"
  fi
done
echo

echo "Application sources:"
for app in "${ROOT_APP_NAME}" "${CHILD_APP_NAME}"; do
  if kubectl -n "${ARGOCD_NAMESPACE}" get application "${app}" >/dev/null 2>&1; then
    kubectl -n "${ARGOCD_NAMESPACE}" get application "${app}" \
      -o jsonpath='Name: {.metadata.name}{"\n"}Repo: {.spec.source.repoURL}{"\n"}Revision: {.spec.source.targetRevision}{"\n"}Path: {.spec.source.path}{"\n"}Automated prune: {.spec.syncPolicy.automated.prune}{"\n"}Automated selfHeal: {.spec.syncPolicy.automated.selfHeal}{"\n\n"}'
  else
    echo "Name: ${app}"
    echo "Status: not found yet"
    echo
  fi
done

echo "Managed namespaces:"
kubectl get namespaces argocd platform-system apps observability security --show-labels

echo
echo "============================================================"
echo "Validation commands:"
echo "  kubectl -n ${ARGOCD_NAMESPACE} describe application ${ROOT_APP_NAME}"
echo "  kubectl -n ${ARGOCD_NAMESPACE} describe application ${CHILD_APP_NAME}"
echo "  kubectl -n ${ARGOCD_NAMESPACE} get app ${ROOT_APP_NAME} ${CHILD_APP_NAME} -o yaml"
echo
echo "Troubleshooting commands:"
echo "  kubectl -n ${ARGOCD_NAMESPACE} get events --sort-by=.lastTimestamp"
echo "  kubectl -n ${ARGOCD_NAMESPACE} logs deploy/argocd-repo-server"
echo "  kubectl -n ${ARGOCD_NAMESPACE} logs statefulset/argocd-application-controller"
echo "  ./scripts/check-argocd-repo-secret.sh"
echo "============================================================"