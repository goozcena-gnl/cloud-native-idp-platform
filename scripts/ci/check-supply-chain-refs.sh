#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

minio_manifest=platform/backup/minio/minio.yaml
if grep -Eq '^[[:space:]]*image:[[:space:]]*([^[:space:]]*/)?(minio|mc):latest([[:space:]]|@|$)' "$minio_manifest"; then
  echo 'MinIO and mc must not use :latest.' >&2
  exit 1
fi
for image in minio mc; do
  if ! grep -Eq "^[[:space:]]*image:[[:space:]]*quay\.io/minio/${image}:[^[:space:]@]+@sha256:[0-9a-f]{64}[[:space:]]*$" "$minio_manifest"; then
    echo "${image} must have a version tag and OCI digest." >&2
    exit 1
  fi
done

mapfile -t bases < <(awk 'toupper($1) == "FROM" { print $2 }' services/demo-grpc/Dockerfile)
if (( ${#bases[@]} == 0 )); then
  echo 'demo-grpc Dockerfile has no base images.' >&2
  exit 1
fi
for base in "${bases[@]}"; do
  if [[ ! "$base" =~ @sha256:[0-9a-f]{64}$ ]]; then
    echo "demo-grpc base image lacks an OCI digest: ${base}" >&2
    exit 1
  fi
done

# Historical GHCR references in the milestone log record an earlier owner.
former_owner=goozdu12
if matches=$(git grep -n -F "${former_owner}/cloud-native-idp-platform" -- . ':(exclude)docs/MILESTONES.md'); then
  printf '%s\n' "$matches"
  echo 'Active references to the former repository owner remain.' >&2
  exit 1
else
  status=$?
  if (( status != 1 )); then
    echo "Repository reference check failed (git grep exit ${status})." >&2
    exit "$status"
  fi
fi

echo 'Supply chain reference checks passed.'
