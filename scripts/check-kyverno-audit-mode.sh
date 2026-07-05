#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-idp-local}"
NAMESPACE="${NAMESPACE:-apps}"
POD_NAME="${POD_NAME:-kyverno-audit-violation}"
POLICY_NAME="${POLICY_NAME:-idp-apps-pod-security-baseline}"

echo "============================================================"
echo "Check Kyverno audit mode"
echo "Context:   ${CONTEXT}"
echo "Namespace: ${NAMESPACE}"
echo "Pod:       ${POD_NAME}"
echo "Policy:    ${POLICY_NAME}"
echo "============================================================"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${CONTEXT}" ]]; then
  echo "ERROR: expected Kubernetes context '${CONTEXT}', got '${CURRENT_CONTEXT}'."
  exit 1
fi

cleanup() {
  kubectl -n "${NAMESPACE}" delete pod "${POD_NAME}" --ignore-not-found=true >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo
echo "ArgoCD applications:"
kubectl -n argocd get application kyverno kyverno-policies \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'

for app in kyverno kyverno-policies; do
  sync_status="$(kubectl -n argocd get application "${app}" -o jsonpath='{.status.sync.status}')"
  health_status="$(kubectl -n argocd get application "${app}" -o jsonpath='{.status.health.status}')"
  [[ "${sync_status}" == "Synced" ]]
  [[ "${health_status}" == "Healthy" ]]
  echo "OK: ArgoCD application ${app} is Synced/Healthy."
done

echo
echo "ClusterPolicy:"
kubectl get clusterpolicy "${POLICY_NAME}"

ready_status="$(kubectl get clusterpolicy "${POLICY_NAME}" -o jsonpath='{.status.ready}')"
[[ "${ready_status}" == "true" ]]
echo "OK: ClusterPolicy ${POLICY_NAME} is ready."

echo
echo "Creating intentionally non-compliant Pod..."
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ${POD_NAME}
spec:
  containers:
    - name: bad-container
      image: busybox:1.36
      command:
        - sh
        - -c
        - sleep 3600
YAML

echo "OK: non-compliant Pod was admitted because policy is in Audit mode."

kubectl -n "${NAMESPACE}" get pod "${POD_NAME}" -o wide

echo
echo "Waiting for Kyverno PolicyReport..."
FOUND="false"

for attempt in {1..18}; do
  if kubectl get policyreport -n "${NAMESPACE}" -o json 2>/dev/null | python -c "
import json, sys
data=json.load(sys.stdin)
policy='${POLICY_NAME}'
pod='${POD_NAME}'
for item in data.get('items', []):
    for r in item.get('results', []):
        resources=r.get('resources', [])
        names=[x.get('name') for x in resources]
        if r.get('policy') == policy and pod in names and r.get('result') in ('fail', 'warn'):
            sys.exit(0)
sys.exit(1)
"; then
    FOUND="true"
    echo "OK: Kyverno reported violations for ${POD_NAME}."
    break
  fi

  echo "  attempt ${attempt}/18: waiting for PolicyReport result..."
  sleep 10
done

if [[ "${FOUND}" != "true" ]]; then
  echo "ERROR: no Kyverno violation found for ${POD_NAME}."
  echo
  echo "PolicyReports:"
  kubectl get policyreport -n "${NAMESPACE}" -o yaml || true
  exit 1
fi

echo
echo "Violation summary:"
kubectl get policyreport -n "${NAMESPACE}" -o json | python -c "
import json, sys
data=json.load(sys.stdin)
policy='${POLICY_NAME}'
pod='${POD_NAME}'
for item in data.get('items', []):
    for r in item.get('results', []):
        resources=r.get('resources', [])
        names=[x.get('name') for x in resources]
        if r.get('policy') == policy and pod in names:
            print('policy=' + str(r.get('policy')))
            print('rule=' + str(r.get('rule')))
            print('result=' + str(r.get('result')))
            print('message=' + str(r.get('message')))
            print('---')
"

echo
echo "Cleaning up test Pod..."
cleanup
echo "OK: test Pod removed."

echo
echo "============================================================"
echo "Kyverno audit mode validated successfully."
echo "============================================================"
