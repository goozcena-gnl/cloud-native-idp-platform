#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-idp-local}"
APP_NAME="${APP_NAME:-kyverno-policies}"
POLICY_NAME="${POLICY_NAME:-idp-apps-pod-security-baseline}"

echo "============================================================"
echo "Check Kyverno policies"
echo "Context: ${CONTEXT}"
echo "App:     ${APP_NAME}"
echo "Policy:  ${POLICY_NAME}"
echo "============================================================"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${CONTEXT}" ]]; then
  echo "ERROR: expected Kubernetes context '${CONTEXT}', got '${CURRENT_CONTEXT}'."
  exit 1
fi

echo
echo "ArgoCD application:"
kubectl -n argocd get application "${APP_NAME}" \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'

SYNC_STATUS="$(
  kubectl -n argocd get application "${APP_NAME}" \
    -o jsonpath='{.status.sync.status}'
)"
HEALTH_STATUS="$(
  kubectl -n argocd get application "${APP_NAME}" \
    -o jsonpath='{.status.health.status}'
)"

[[ "${SYNC_STATUS}" == "Synced" ]]
echo "OK: ArgoCD application ${APP_NAME} is Synced."

[[ "${HEALTH_STATUS}" == "Healthy" ]]
echo "OK: ArgoCD application ${APP_NAME} is Healthy."

echo
echo "ClusterPolicy:"
kubectl get clusterpolicy "${POLICY_NAME}"

READY_STATUS="$(
  kubectl get clusterpolicy "${POLICY_NAME}" \
    -o jsonpath='{.status.ready}'
)"
[[ "${READY_STATUS}" == "true" ]]
echo "OK: ClusterPolicy ${POLICY_NAME} is ready."

echo
echo "Policy rules:"
kubectl get clusterpolicy "${POLICY_NAME}" -o jsonpath='{range .spec.rules[*]}{.name}{"\n"}{end}'

for rule in \
  require-pod-security-context \
  disallow-privilege-escalation \
  require-read-only-root-filesystem \
  require-drop-all-capabilities \
  require-resource-requests-and-limits
do
  kubectl get clusterpolicy "${POLICY_NAME}" -o jsonpath='{range .spec.rules[*]}{.name}{"\n"}{end}' \
    | grep -qx "${rule}"
  echo "OK: rule ${rule} exists."
done

echo
echo "Validation failure actions:"
kubectl get clusterpolicy "${POLICY_NAME}" \
  -o jsonpath='{range .spec.rules[*]}{.name}{": "}{.validate.failureAction}{"\n"}{end}'

if kubectl get clusterpolicy "${POLICY_NAME}" \
  -o jsonpath='{range .spec.rules[*]}{.validate.failureAction}{"\n"}{end}' \
  | grep -v '^Audit$'
then
  echo "ERROR: all baseline rules must be in Audit mode for this phase."
  exit 1
fi

echo "OK: all baseline rules are in Audit mode."

echo
echo "Policy reports:"
kubectl get policyreport -n apps || true
kubectl get clusterpolicyreport || true

echo
echo "============================================================"
echo "Kyverno policies validated successfully."
echo "============================================================"
