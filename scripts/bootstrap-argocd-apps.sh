#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
PROJECT_MANIFEST="${PROJECT_MANIFEST:-platform/argocd/projects/idp-platform-project.yaml}"
ROOT_APP_MANIFEST="${ROOT_APP_MANIFEST:-platform/argocd/bootstrap/root-app.yaml}"
PROJECT_NAME="${PROJECT_NAME:-idp-platform}"
ROOT_APP_NAME="${ROOT_APP_NAME:-idp-root}"
CHILD_APP_NAME="${CHILD_APP_NAME:-platform-namespaces}"

echo "============================================================"
echo "Bootstrap ArgoCD Applications"
echo "Expected context: ${EXPECTED_CONTEXT}"
echo "Namespace:        ${ARGOCD_NAMESPACE}"
echo "Project:          ${PROJECT_NAME}"
echo "Root app:         ${ROOT_APP_NAME}"
echo "Child app:        ${CHILD_APP_NAME}"
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

for manifest in "${PROJECT_MANIFEST}" "${ROOT_APP_MANIFEST}"; do
  if [[ ! -f "${manifest}" ]]; then
    echo "ERROR: manifest not found: ${manifest}"
    exit 1
  fi
done

kubectl get namespace "${ARGOCD_NAMESPACE}" >/dev/null
kubectl get crd appprojects.argoproj.io applications.argoproj.io >/dev/null

if [[ -x ./scripts/check-argocd-repo-secret.sh ]]; then
  echo "Validating private repository Secret without printing credentials..."
  ./scripts/check-argocd-repo-secret.sh
  echo
else
  echo "WARNING: scripts/check-argocd-repo-secret.sh is not executable; skipping repo Secret validation."
  echo
fi

echo "Server-side dry-run for ArgoCD project and root app..."
kubectl apply --dry-run=server -f "${PROJECT_MANIFEST}"
kubectl apply --dry-run=server -f "${ROOT_APP_MANIFEST}"

echo
echo "Applying AppProject and root Application..."
kubectl apply -f "${PROJECT_MANIFEST}"
kubectl apply -f "${ROOT_APP_MANIFEST}"

echo
echo "Current ArgoCD Applications:"
kubectl -n "${ARGOCD_NAMESPACE}" get applications.argoproj.io

echo
echo "============================================================"
echo "GitOps bootstrap submitted."
echo
echo "Validation commands:"
echo "  ./scripts/check-argocd-apps.sh"
echo "  kubectl -n ${ARGOCD_NAMESPACE} get appprojects.argoproj.io ${PROJECT_NAME}"
echo "  kubectl -n ${ARGOCD_NAMESPACE} get applications.argoproj.io ${ROOT_APP_NAME} ${CHILD_APP_NAME}"
echo
echo "Troubleshooting commands:"
echo "  kubectl -n ${ARGOCD_NAMESPACE} describe application ${ROOT_APP_NAME}"
echo "  kubectl -n ${ARGOCD_NAMESPACE} describe application ${CHILD_APP_NAME}"
echo "  kubectl -n ${ARGOCD_NAMESPACE} logs deploy/argocd-repo-server"
echo "  kubectl -n ${ARGOCD_NAMESPACE} logs statefulset/argocd-application-controller"
echo "============================================================"