#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-idp-local}"
NAMESPACE="${NAMESPACE:-backstage}"
SECRET_NAME="${SECRET_NAME:-backstage-postgres}"
POSTGRES_USER="${POSTGRES_USER:-backstage}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-backstage-dev-password}"

echo "============================================================"
echo "Configure Backstage local secrets"
echo "Context:   ${CONTEXT}"
echo "Namespace: ${NAMESPACE}"
echo "Secret:    ${SECRET_NAME}"
echo "============================================================"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${CONTEXT}" ]]; then
  echo "ERROR: expected Kubernetes context '${CONTEXT}', got '${CURRENT_CONTEXT}'."
  exit 1
fi

kubectl create namespace "${NAMESPACE}" \
  --dry-run=client \
  -o yaml \
  | kubectl apply -f -

kubectl label namespace "${NAMESPACE}" \
  app.kubernetes.io/name=backstage \
  app.kubernetes.io/part-of=idp-platform \
  idp.platform/tier=developer-experience \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted \
  --overwrite

kubectl -n "${NAMESPACE}" create secret generic "${SECRET_NAME}" \
  --from-literal=username="${POSTGRES_USER}" \
  --from-literal=password="${POSTGRES_PASSWORD}" \
  --dry-run=client \
  -o yaml \
  | kubectl apply -f -

kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}"

echo
echo "============================================================"
echo "Backstage local secrets configured successfully."
echo "============================================================"
