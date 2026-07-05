#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-idp-local}"
NAMESPACE="${NAMESPACE:-apps}"
DEPLOYMENT="${DEPLOYMENT:-demo-grpc}"

echo "============================================================"
echo "Check demo-grpc security baseline"
echo "Context:    ${CONTEXT}"
echo "Namespace:  ${NAMESPACE}"
echo "Deployment: ${DEPLOYMENT}"
echo "============================================================"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${CONTEXT}" ]]; then
  echo "ERROR: expected Kubernetes context '${CONTEXT}', got '${CURRENT_CONTEXT}'."
  exit 1
fi

echo
echo "ArgoCD application:"
kubectl -n argocd get application demo-grpc \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'

echo
echo "Deployment image:"
kubectl -n "${NAMESPACE}" get deploy "${DEPLOYMENT}" \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

echo
echo "Rendered Helm security baseline:"
helm template "${DEPLOYMENT}" charts/demo-grpc --namespace "${NAMESPACE}" >/tmp/demo-grpc-rendered-security.yaml

grep -q "runAsNonRoot: true" /tmp/demo-grpc-rendered-security.yaml
echo "OK: Helm render contains runAsNonRoot=true."

grep -q "runAsUser: 65532" /tmp/demo-grpc-rendered-security.yaml
echo "OK: Helm render contains runAsUser=65532."

grep -q "runAsGroup: 65532" /tmp/demo-grpc-rendered-security.yaml
echo "OK: Helm render contains runAsGroup=65532."

grep -q "type: RuntimeDefault" /tmp/demo-grpc-rendered-security.yaml
echo "OK: Helm render contains seccompProfile RuntimeDefault."

grep -q "allowPrivilegeEscalation: false" /tmp/demo-grpc-rendered-security.yaml
echo "OK: Helm render contains allowPrivilegeEscalation=false."

grep -q "readOnlyRootFilesystem: true" /tmp/demo-grpc-rendered-security.yaml
echo "OK: Helm render contains readOnlyRootFilesystem=true."

grep -q -- "- ALL" /tmp/demo-grpc-rendered-security.yaml
echo "OK: Helm render drops all Linux capabilities."

grep -q "requests:" /tmp/demo-grpc-rendered-security.yaml
grep -q "limits:" /tmp/demo-grpc-rendered-security.yaml
echo "OK: Helm render contains resource requests and limits."

echo
echo "Live Kubernetes security baseline:"

RUN_AS_NON_ROOT="$(
  kubectl -n "${NAMESPACE}" get deploy "${DEPLOYMENT}" \
    -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}'
)"
[[ "${RUN_AS_NON_ROOT}" == "true" ]]
echo "OK: live deployment runAsNonRoot=true."

RUN_AS_USER="$(
  kubectl -n "${NAMESPACE}" get deploy "${DEPLOYMENT}" \
    -o jsonpath='{.spec.template.spec.securityContext.runAsUser}'
)"
[[ "${RUN_AS_USER}" == "65532" ]]
echo "OK: live deployment runAsUser=65532."

RUN_AS_GROUP="$(
  kubectl -n "${NAMESPACE}" get deploy "${DEPLOYMENT}" \
    -o jsonpath='{.spec.template.spec.securityContext.runAsGroup}'
)"
[[ "${RUN_AS_GROUP}" == "65532" ]]
echo "OK: live deployment runAsGroup=65532."

SECCOMP_TYPE="$(
  kubectl -n "${NAMESPACE}" get deploy "${DEPLOYMENT}" \
    -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}'
)"
[[ "${SECCOMP_TYPE}" == "RuntimeDefault" ]]
echo "OK: live deployment seccompProfile=RuntimeDefault."

ALLOW_PRIV_ESC="$(
  kubectl -n "${NAMESPACE}" get deploy "${DEPLOYMENT}" \
    -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}'
)"
[[ "${ALLOW_PRIV_ESC}" == "false" ]]
echo "OK: live container allowPrivilegeEscalation=false."

READ_ONLY_ROOT_FS="$(
  kubectl -n "${NAMESPACE}" get deploy "${DEPLOYMENT}" \
    -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}'
)"
[[ "${READ_ONLY_ROOT_FS}" == "true" ]]
echo "OK: live container readOnlyRootFilesystem=true."

CAP_DROP="$(
  kubectl -n "${NAMESPACE}" get deploy "${DEPLOYMENT}" \
    -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.drop[0]}'
)"
[[ "${CAP_DROP}" == "ALL" ]]
echo "OK: live container drops all Linux capabilities."

CPU_REQUEST="$(
  kubectl -n "${NAMESPACE}" get deploy "${DEPLOYMENT}" \
    -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}'
)"
MEM_REQUEST="$(
  kubectl -n "${NAMESPACE}" get deploy "${DEPLOYMENT}" \
    -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}'
)"
CPU_LIMIT="$(
  kubectl -n "${NAMESPACE}" get deploy "${DEPLOYMENT}" \
    -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}'
)"
MEM_LIMIT="$(
  kubectl -n "${NAMESPACE}" get deploy "${DEPLOYMENT}" \
    -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'
)"

[[ -n "${CPU_REQUEST}" && -n "${MEM_REQUEST}" && -n "${CPU_LIMIT}" && -n "${MEM_LIMIT}" ]]
echo "OK: live container has CPU/memory requests and limits."

echo
echo "Namespace Pod Security Admission labels:"
kubectl get ns "${NAMESPACE}" \
  -o custom-columns='NAME:.metadata.name,PSA_ENFORCE:.metadata.labels.pod-security\.kubernetes\.io/enforce,PSA_WARN:.metadata.labels.pod-security\.kubernetes\.io/warn,PSA_AUDIT:.metadata.labels.pod-security\.kubernetes\.io/audit'

PSA_WARN="$(
  kubectl get ns "${NAMESPACE}" \
    -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}'
)"
PSA_AUDIT="$(
  kubectl get ns "${NAMESPACE}" \
    -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/audit}'
)"

[[ "${PSA_WARN}" == "restricted" ]]
echo "OK: apps namespace has PSA warn=restricted."

[[ "${PSA_AUDIT}" == "restricted" ]]
echo "OK: apps namespace has PSA audit=restricted."

echo
echo "============================================================"
echo "demo-grpc security baseline validated successfully."
echo "============================================================"
