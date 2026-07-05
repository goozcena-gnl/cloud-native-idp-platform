#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-idp-local}"
NAMESPACE="${NAMESPACE:-kyverno}"

echo "============================================================"
echo "Check Kyverno stack"
echo "Context:   ${CONTEXT}"
echo "Namespace: ${NAMESPACE}"
echo "============================================================"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${CONTEXT}" ]]; then
  echo "ERROR: expected Kubernetes context '${CONTEXT}', got '${CURRENT_CONTEXT}'."
  exit 1
fi

echo
echo "ArgoCD application:"
kubectl -n argocd get application kyverno \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'

SYNC_STATUS="$(
  kubectl -n argocd get application kyverno \
    -o jsonpath='{.status.sync.status}'
)"
HEALTH_STATUS="$(
  kubectl -n argocd get application kyverno \
    -o jsonpath='{.status.health.status}'
)"

[[ "${SYNC_STATUS}" == "Synced" ]]
echo "OK: ArgoCD application kyverno is Synced."

[[ "${HEALTH_STATUS}" == "Healthy" ]]
echo "OK: ArgoCD application kyverno is Healthy."

echo
echo "Namespace:"
kubectl get ns "${NAMESPACE}" --show-labels

echo
echo "Deployments:"
kubectl -n "${NAMESPACE}" get deploy

for deployment in \
  kyverno-admission-controller \
  kyverno-background-controller \
  kyverno-cleanup-controller \
  kyverno-reports-controller
do
  kubectl -n "${NAMESPACE}" rollout status "deployment/${deployment}" --timeout=180s
  echo "OK: ${deployment} rolled out."
done

echo
echo "Pods:"
kubectl -n "${NAMESPACE}" get pods -o wide

echo
echo "CRDs:"
CRD_COUNT="$(kubectl get crd | grep -ci kyverno || true)"
if [[ "${CRD_COUNT}" -lt 1 ]]; then
  echo "ERROR: no Kyverno CRDs found."
  exit 1
fi
kubectl get crd | grep -i kyverno
echo "OK: Kyverno CRDs found."

echo
echo "API resources:"
kubectl api-resources | grep -i kyverno || {
  echo "ERROR: no Kyverno API resources found."
  exit 1
}
echo "OK: Kyverno API resources found."

echo
echo "Webhooks:"
WEBHOOK_COUNT="$(
  kubectl get validatingwebhookconfiguration,mutatingwebhookconfiguration \
    | grep -ci kyverno || true
)"
if [[ "${WEBHOOK_COUNT}" -lt 1 ]]; then
  echo "ERROR: no Kyverno webhook configurations found."
  exit 1
fi

kubectl get validatingwebhookconfiguration,mutatingwebhookconfiguration \
  | grep -i kyverno
echo "OK: Kyverno webhook configurations found."

echo
echo "============================================================"
echo "Kyverno stack validated successfully."
echo "============================================================"
