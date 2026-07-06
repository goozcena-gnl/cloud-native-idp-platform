#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-idp-local}"
NAMESPACE="${NAMESPACE:-falco}"
APP_NAME="${APP_NAME:-falco}"
TEST_NAMESPACE="${TEST_NAMESPACE:-falco-test}"
TEST_DEPLOYMENT="${TEST_DEPLOYMENT:-falco-nginx-test}"

echo "============================================================"
echo "Check Falco runtime security"
echo "Context:        ${CONTEXT}"
echo "Namespace:      ${NAMESPACE}"
echo "App:            ${APP_NAME}"
echo "Test namespace: ${TEST_NAMESPACE}"
echo "============================================================"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${CONTEXT}" ]]; then
  echo "ERROR: expected Kubernetes context '${CONTEXT}', got '${CURRENT_CONTEXT}'."
  exit 1
fi

cleanup() {
  kubectl delete namespace "${TEST_NAMESPACE}" --ignore-not-found=true >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo
echo "ArgoCD application:"
kubectl -n argocd get application "${APP_NAME}" \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'

SYNC_STATUS="$(kubectl -n argocd get application "${APP_NAME}" -o jsonpath='{.status.sync.status}')"
HEALTH_STATUS="$(kubectl -n argocd get application "${APP_NAME}" -o jsonpath='{.status.health.status}')"

[[ "${SYNC_STATUS}" == "Synced" ]]
[[ "${HEALTH_STATUS}" == "Healthy" ]]
echo "OK: ArgoCD application ${APP_NAME} is Synced/Healthy."

echo
echo "Namespace:"
kubectl get ns "${NAMESPACE}" --show-labels

echo
echo "Falco resources:"
kubectl -n "${NAMESPACE}" get daemonset,pods,svc -o wide

kubectl -n "${NAMESPACE}" rollout status daemonset/falco --timeout=240s
echo "OK: Falco DaemonSet rolled out."

echo
echo "Checking Falco logs for startup errors..."
if kubectl -n "${NAMESPACE}" logs -l app.kubernetes.io/name=falco -c falco --since=10m \
  | grep -Ei "error|fatal|unable|failed" \
  | grep -Eiv "non-fatal|warning|libpman: disabled BPF iterators" >/tmp/check-falco-errors.log
then
  echo "ERROR: suspicious Falco startup errors found:"
  cat /tmp/check-falco-errors.log
  exit 1
fi

echo "OK: no blocking Falco startup errors detected."

echo
echo "Creating Falco test workload..."
cleanup

kubectl create namespace "${TEST_NAMESPACE}"

kubectl -n "${TEST_NAMESPACE}" create deployment "${TEST_DEPLOYMENT}" --image=nginx:1.27-alpine

kubectl -n "${TEST_NAMESPACE}" rollout status "deployment/${TEST_DEPLOYMENT}" --timeout=180s

TEST_POD="$(
  kubectl -n "${TEST_NAMESPACE}" get pods -l app="${TEST_DEPLOYMENT}" \
    -o jsonpath='{.items[0].metadata.name}'
)"

echo "OK: test pod created: ${TEST_POD}"

echo
echo "Triggering Falco rule by reading /etc/shadow..."
kubectl -n "${TEST_NAMESPACE}" exec "${TEST_POD}" -- cat /etc/shadow >/tmp/check-falco-shadow-output.txt || true

echo
echo "Waiting for Falco event..."
FOUND="false"

for attempt in {1..18}; do
  if kubectl -n "${NAMESPACE}" logs -l app.kubernetes.io/name=falco -c falco --since=5m \
    | grep -Ei "Sensitive file opened|/etc/shadow|Warning|WARNING" >/tmp/check-falco-event.log
  then
    FOUND="true"
    echo "OK: Falco detected the runtime event."
    break
  fi

  echo "  attempt ${attempt}/18: waiting for Falco event..."
  sleep 10
done

if [[ "${FOUND}" != "true" ]]; then
  echo "ERROR: Falco did not detect the test event."
  echo
  echo "Recent Falco logs:"
  kubectl -n "${NAMESPACE}" logs -l app.kubernetes.io/name=falco -c falco --tail=300 || true
  exit 1
fi

echo
echo "Falco event:"
cat /tmp/check-falco-event.log | tail -5

echo
echo "Cleaning up test namespace..."
cleanup
echo "OK: test namespace removed."

echo
echo "============================================================"
echo "Falco runtime security validated successfully."
echo "============================================================"
