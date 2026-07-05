#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-idp-local}"
NAMESPACE="${NAMESPACE:-apps}"
POD_NAME="${POD_NAME:-kyverno-audit-violation}"
POLICY_NAME="${POLICY_NAME:-idp-apps-pod-security-baseline}"

export POLICY_NAME POD_NAME

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

ready_status="$(
  kubectl get clusterpolicy "${POLICY_NAME}" -o json | python -c '
import json
import sys

obj = json.load(sys.stdin)
conditions = obj.get("status", {}).get("conditions", [])

for condition in conditions:
    if condition.get("type") == "Ready":
        print(condition.get("status", ""))
        break
'
)"

ready_status_lower="$(echo "${ready_status}" | tr '[:upper:]' '[:lower:]')"
[[ "${ready_status_lower}" == "true" ]]
echo "OK: ClusterPolicy ${POLICY_NAME} is ready."

echo
echo "Cleaning up any previous test Pod..."
cleanup

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
  if POLICY_NAME="${POLICY_NAME}" POD_NAME="${POD_NAME}" \
    kubectl get policyreport -n "${NAMESPACE}" -o json 2>/dev/null | python -c '
import json
import os
import sys

data = json.load(sys.stdin)
policy = os.environ["POLICY_NAME"]
pod = os.environ["POD_NAME"]

for item in data.get("items", []):
    scope = item.get("scope", {})
    scope_name = scope.get("name")

    for result in item.get("results", []):
        resources = result.get("resources", [])
        resource_names = [resource.get("name") for resource in resources]

        matches_policy = result.get("policy") == policy
        matches_pod = scope_name == pod or pod in resource_names
        matches_result = result.get("result") in ("fail", "warn")

        if matches_policy and matches_pod and matches_result:
            sys.exit(0)

sys.exit(1)
'; then
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
POLICY_NAME="${POLICY_NAME}" POD_NAME="${POD_NAME}" \
  kubectl get policyreport -n "${NAMESPACE}" -o json | python -c '
import json
import os
import sys

data = json.load(sys.stdin)
policy = os.environ["POLICY_NAME"]
pod = os.environ["POD_NAME"]

for item in data.get("items", []):
    scope = item.get("scope", {})
    scope_name = scope.get("name")
    scope_kind = scope.get("kind")
    scope_namespace = scope.get("namespace")

    for result in item.get("results", []):
        resources = result.get("resources", [])
        resource_names = [resource.get("name") for resource in resources]

        matches_policy = result.get("policy") == policy
        matches_pod = scope_name == pod or pod in resource_names

        if matches_policy and matches_pod:
            print("policy=" + str(result.get("policy")))
            print("rule=" + str(result.get("rule")))
            print("result=" + str(result.get("result")))
            print("resource=" + str(scope_kind) + " " + str(scope_namespace) + "/" + str(scope_name))
            print("message=" + str(result.get("message")))
            print("---")
'

echo
echo "Cleaning up test Pod..."
cleanup
echo "OK: test Pod removed."

echo
echo "============================================================"
echo "Kyverno audit mode validated successfully."
echo "============================================================"
