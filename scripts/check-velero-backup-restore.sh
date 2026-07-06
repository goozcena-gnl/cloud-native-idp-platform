#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-idp-local}"
VELERO_NAMESPACE="${VELERO_NAMESPACE:-velero}"
TEST_NAMESPACE="${TEST_NAMESPACE:-velero-restore-test}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d%H%M%S)}"
BACKUP_NAME="${BACKUP_NAME:-idp-velero-drill-${RUN_ID}}"
RESTORE_NAME="${RESTORE_NAME:-${BACKUP_NAME}-restore}"
CONFIGMAP_NAME="${CONFIGMAP_NAME:-restore-proof}"

echo "============================================================"
echo "Check Velero backup and restore"
echo "Context:          ${CONTEXT}"
echo "Velero namespace: ${VELERO_NAMESPACE}"
echo "Test namespace:   ${TEST_NAMESPACE}"
echo "Backup:           ${BACKUP_NAME}"
echo "Restore:          ${RESTORE_NAME}"
echo "============================================================"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${CONTEXT}" ]]; then
  echo "ERROR: expected Kubernetes context '${CONTEXT}', got '${CURRENT_CONTEXT}'."
  exit 1
fi

cleanup() {
  kubectl delete restore "${RESTORE_NAME}" -n "${VELERO_NAMESPACE}" --ignore-not-found=true >/dev/null 2>&1 || true
  kubectl delete backup "${BACKUP_NAME}" -n "${VELERO_NAMESPACE}" --ignore-not-found=true >/dev/null 2>&1 || true
  kubectl delete namespace "${TEST_NAMESPACE}" --ignore-not-found=true >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo
echo "ArgoCD applications:"
kubectl -n argocd get application velero velero-minio \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'

for app in velero velero-minio; do
  sync_status="$(kubectl -n argocd get application "${app}" -o jsonpath='{.status.sync.status}')"
  health_status="$(kubectl -n argocd get application "${app}" -o jsonpath='{.status.health.status}')"

  [[ "${sync_status}" == "Synced" ]]
  [[ "${health_status}" == "Healthy" ]]

  echo "OK: ArgoCD application ${app} is Synced/Healthy."
done

echo
echo "BackupStorageLocation:"
kubectl -n "${VELERO_NAMESPACE}" get backupstoragelocation

bsl_phase="$(kubectl -n "${VELERO_NAMESPACE}" get backupstoragelocation default -o jsonpath='{.status.phase}')"
[[ "${bsl_phase}" == "Available" ]]
echo "OK: BackupStorageLocation default is Available."

echo
echo "Cleaning previous test resources..."
cleanup

echo
echo "Creating test namespace and ConfigMap..."
kubectl create namespace "${TEST_NAMESPACE}"

kubectl -n "${TEST_NAMESPACE}" create configmap "${CONFIGMAP_NAME}" \
  --from-literal=proof="velero-backup-restore-ok" \
  --from-literal=created-by="cloud-native-idp-platform"

kubectl -n "${TEST_NAMESPACE}" get configmap "${CONFIGMAP_NAME}" -o yaml

echo
echo "Creating Velero Backup..."
cat <<YAML | kubectl apply -f -
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: ${BACKUP_NAME}
  namespace: ${VELERO_NAMESPACE}
  labels:
    app.kubernetes.io/name: velero-backup-restore-drill
    app.kubernetes.io/part-of: idp-platform
    idp.platform/tier: backup
spec:
  includedNamespaces:
    - ${TEST_NAMESPACE}
  storageLocation: default
  ttl: 24h0m0s
YAML

echo
echo "Waiting for Backup completion..."
for attempt in {1..36}; do
  phase="$(kubectl -n "${VELERO_NAMESPACE}" get backup "${BACKUP_NAME}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"

  if [[ "${phase}" == "Completed" ]]; then
    echo "OK: Backup completed."
    break
  fi

  if [[ "${phase}" == "Failed" || "${phase}" == "PartiallyFailed" ]]; then
    echo "ERROR: Backup ended with phase ${phase}."
    kubectl -n "${VELERO_NAMESPACE}" describe backup "${BACKUP_NAME}" || true
    exit 1
  fi

  echo "  attempt ${attempt}/36: backup phase=${phase:-unknown}"
  sleep 5
done

phase="$(kubectl -n "${VELERO_NAMESPACE}" get backup "${BACKUP_NAME}" -o jsonpath='{.status.phase}')"
[[ "${phase}" == "Completed" ]]

kubectl -n "${VELERO_NAMESPACE}" get backup "${BACKUP_NAME}"

echo
echo "Deleting test namespace to simulate data loss..."
kubectl delete namespace "${TEST_NAMESPACE}" --wait=true

echo
echo "Creating Velero Restore..."
cat <<YAML | kubectl apply -f -
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: ${RESTORE_NAME}
  namespace: ${VELERO_NAMESPACE}
  labels:
    app.kubernetes.io/name: velero-backup-restore-drill
    app.kubernetes.io/part-of: idp-platform
    idp.platform/tier: backup
spec:
  backupName: ${BACKUP_NAME}
YAML

echo
echo "Waiting for Restore completion..."
for attempt in {1..36}; do
  phase="$(kubectl -n "${VELERO_NAMESPACE}" get restore "${RESTORE_NAME}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"

  if [[ "${phase}" == "Completed" ]]; then
    echo "OK: Restore completed."
    break
  fi

  if [[ "${phase}" == "Failed" || "${phase}" == "PartiallyFailed" ]]; then
    echo "ERROR: Restore ended with phase ${phase}."
    kubectl -n "${VELERO_NAMESPACE}" describe restore "${RESTORE_NAME}" || true
    exit 1
  fi

  echo "  attempt ${attempt}/36: restore phase=${phase:-unknown}"
  sleep 5
done

phase="$(kubectl -n "${VELERO_NAMESPACE}" get restore "${RESTORE_NAME}" -o jsonpath='{.status.phase}')"
[[ "${phase}" == "Completed" ]]

kubectl -n "${VELERO_NAMESPACE}" get restore "${RESTORE_NAME}"

echo
echo "Validating restored ConfigMap..."
kubectl -n "${TEST_NAMESPACE}" get configmap "${CONFIGMAP_NAME}" -o yaml

proof="$(
  kubectl -n "${TEST_NAMESPACE}" get configmap "${CONFIGMAP_NAME}" \
    -o jsonpath='{.data.proof}'
)"

[[ "${proof}" == "velero-backup-restore-ok" ]]
echo "OK: restored ConfigMap contains expected proof value."

echo
echo "Cleaning drill resources..."
cleanup
echo "OK: drill resources removed."

echo
echo "============================================================"
echo "Velero backup and restore validated successfully."
echo "============================================================"
