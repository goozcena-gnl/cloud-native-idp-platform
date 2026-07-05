#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-idp-local}"
NAMESPACE="${NAMESPACE:-opencost}"
APP_NAME="${APP_NAME:-opencost}"
LOCAL_PORT="${LOCAL_PORT:-19003}"

echo "============================================================"
echo "Check OpenCost stack"
echo "Context:    ${CONTEXT}"
echo "Namespace:  ${NAMESPACE}"
echo "App:        ${APP_NAME}"
echo "Local port: ${LOCAL_PORT}"
echo "============================================================"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${CONTEXT}" ]]; then
  echo "ERROR: expected Kubernetes context '${CONTEXT}', got '${CURRENT_CONTEXT}'."
  exit 1
fi

cleanup() {
  if [[ -n "${PF_PID:-}" ]]; then
    kill "${PF_PID}" >/dev/null 2>&1 || true
  fi
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
echo "Workloads:"
kubectl -n "${NAMESPACE}" get deploy,pods,svc -o wide

kubectl -n "${NAMESPACE}" rollout status deployment/opencost --timeout=180s
echo "OK: OpenCost deployment rolled out."

echo
echo "ServiceMonitor:"
kubectl -n "${NAMESPACE}" get servicemonitor || true

echo
echo "Starting OpenCost port-forward..."
kubectl -n "${NAMESPACE}" port-forward svc/opencost "${LOCAL_PORT}:9003" >/tmp/check-opencost-pf.log 2>&1 &
PF_PID=$!

sleep 5

echo
echo "Checking OpenCost allocation API..."
ALLOCATION_RESPONSE="$(
  curl -fsS "http://127.0.0.1:${LOCAL_PORT}/allocation/compute?window=1h&aggregate=namespace"
)"

RESPONSE="${ALLOCATION_RESPONSE}" python - <<'PY'
import json
import os
import sys

raw = os.environ["RESPONSE"]
data = json.loads(raw)

if not isinstance(data, dict):
    print("ERROR: allocation response is not a JSON object.")
    sys.exit(1)

if "code" in data and data.get("code") not in (200, "200"):
    print("ERROR: unexpected OpenCost response code:", data.get("code"))
    print(raw[:1000])
    sys.exit(1)

if "data" not in data:
    print("ERROR: OpenCost response has no data field.")
    print(raw[:1000])
    sys.exit(1)

print("OK: OpenCost allocation API returned JSON data.")
PY

echo
echo "============================================================"
echo "OpenCost stack validated successfully."
echo "============================================================"
