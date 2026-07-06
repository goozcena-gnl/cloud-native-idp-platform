#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-velero}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-minio}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minio12345}"
MINIO_BUCKET="${MINIO_BUCKET:-velero}"

echo "============================================================"
echo "Configure Velero MinIO credentials"
echo "Namespace: ${NAMESPACE}"
echo "Bucket:    ${MINIO_BUCKET}"
echo "============================================================"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl label namespace "${NAMESPACE}" \
  app.kubernetes.io/name=velero \
  app.kubernetes.io/part-of=idp-platform \
  idp.platform/tier=backup \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted \
  --overwrite

kubectl -n "${NAMESPACE}" create secret generic velero-minio-root \
  --from-literal=root-user="${MINIO_ROOT_USER}" \
  --from-literal=root-password="${MINIO_ROOT_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

CLOUD_CREDENTIALS="$(
cat <<CREDS
[default]
aws_access_key_id=${MINIO_ROOT_USER}
aws_secret_access_key=${MINIO_ROOT_PASSWORD}
CREDS
)"

kubectl -n "${NAMESPACE}" create secret generic cloud-credentials \
  --from-literal=cloud="${CLOUD_CREDENTIALS}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo
echo "Secrets:"
kubectl -n "${NAMESPACE}" get secret velero-minio-root cloud-credentials

echo
echo "============================================================"
echo "Velero MinIO credentials configured successfully."
echo "============================================================"
