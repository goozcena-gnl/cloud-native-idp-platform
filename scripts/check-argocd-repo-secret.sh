#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
SECRET_NAME="${ARGOCD_REPO_SECRET_NAME:-argocd-repo-cloud-native-idp-platform}"

echo "============================================================"
echo "Check ArgoCD repository Secret"
echo "Namespace:   ${NAMESPACE}"
echo "Secret name: ${SECRET_NAME}"
echo "============================================================"
echo

if ! kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}" >/dev/null 2>&1; then
  echo "ERROR: Secret not found."
  exit 1
fi

echo "Secret exists."

SECRET_TYPE="$(kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}" -o jsonpath='{.metadata.labels.argocd\.argoproj\.io/secret-type}')"
REPO_TYPE="$(kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}" -o jsonpath='{.data.type}' | base64 -d)"
REPO_URL="$(kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}" -o jsonpath='{.data.url}' | base64 -d)"
USERNAME_PRESENT="$(kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}" -o jsonpath='{.data.username}' | wc -c)"
PASSWORD_PRESENT="$(kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}" -o jsonpath='{.data.password}' | wc -c)"

echo "ArgoCD secret type: ${SECRET_TYPE}"
echo "Repository type:    ${REPO_TYPE}"
echo "Repository URL:     ${REPO_URL}"

if [[ "${USERNAME_PRESENT}" -gt 0 ]]; then
  echo "Username:           present"
else
  echo "Username:           missing"
fi

if [[ "${PASSWORD_PRESENT}" -gt 0 ]]; then
  echo "Password/token:     present but hidden"
else
  echo "Password/token:     missing"
fi

if [[ "${SECRET_TYPE}" != "repository" ]]; then
  echo "ERROR: Secret label is incorrect."
  exit 1
fi

if [[ "${REPO_TYPE}" != "git" ]]; then
  echo "ERROR: Repository type is not git."
  exit 1
fi

echo
echo "Secret structure looks valid."
echo "============================================================"
