#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-idp-local}"
NAMESPACE="${NAMESPACE:-backstage}"
LOCAL_PORT="${LOCAL_PORT:-7007}"
TEMPLATE_NAME="${TEMPLATE_NAME:-go-grpc-service}"

echo "============================================================"
echo "Check Backstage software template"
echo "Context:   ${CONTEXT}"
echo "Namespace: ${NAMESPACE}"
echo "Template:  ${TEMPLATE_NAME}"
echo "URL:       http://127.0.0.1:${LOCAL_PORT}"
echo "============================================================"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${CONTEXT}" ]]; then
  echo "ERROR: expected Kubernetes context '${CONTEXT}', got '${CURRENT_CONTEXT}'."
  exit 1
fi

required_files=(
  "developer-portal/backstage/templates/go-grpc-service/template.yaml"
  "developer-portal/backstage/templates/go-grpc-service/content/README.md"
  "developer-portal/backstage/templates/go-grpc-service/content/catalog-info.yaml"
  "developer-portal/backstage/templates/go-grpc-service/content/golden-path-checklist.md"
)

for file in "${required_files[@]}"; do
  [[ -f "${file}" ]]
  echo "OK: ${file}"
done

echo
echo "Checking Backstage app state..."
kubectl -n argocd get application backstage \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'

[[ "$(kubectl -n argocd get application backstage -o jsonpath='{.status.sync.status}')" == "Synced" ]]
[[ "$(kubectl -n argocd get application backstage -o jsonpath='{.status.health.status}')" == "Healthy" ]]

echo "OK: Backstage ArgoCD application is Synced/Healthy."

echo
echo "Checking template through Backstage catalog API..."

kubectl -n "${NAMESPACE}" port-forward svc/backstage "${LOCAL_PORT}:7007" >/tmp/backstage-template-port-forward.log 2>&1 &
PF_PID="$!"

cleanup() {
  kill "${PF_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 5

TEMPLATE_URL="http://127.0.0.1:${LOCAL_PORT}/api/catalog/entities/by-name/template/default/${TEMPLATE_NAME}"

for i in {1..30}; do
  if curl -fsS "${TEMPLATE_URL}" >/tmp/backstage-template.json; then
    if grep -q '"kind":"Template"' /tmp/backstage-template.json; then
      break
    fi
  fi

  echo "Waiting for Backstage template entity... attempt ${i}/30"
  sleep 5
done

grep -q '"kind":"Template"' /tmp/backstage-template.json
grep -q "\"name\":\"${TEMPLATE_NAME}\"" /tmp/backstage-template.json

echo "OK: Template/${TEMPLATE_NAME} is visible through the Backstage catalog API."

echo
echo "============================================================"
echo "Backstage software template validated successfully."
echo "============================================================"
