#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "Check evidence index"
echo "============================================================"

INDEX="docs/EVIDENCE_INDEX.md"

if [[ ! -f "${INDEX}" ]]; then
  echo "ERROR: missing ${INDEX}"
  exit 1
fi

required_sections=(
  "# Evidence Index"
  "## Final validation"
  "## Observability / SRE"
  "## Security Governance"
  "## Backup and Disaster Recovery"
  "## Secrets Management"
  "## Developer Portal / Backstage"
  "## Evidence folders"
  "## Related documentation"
)

for section in "${required_sections[@]}"; do
  if ! grep -qF "${section}" "${INDEX}"; then
    echo "ERROR: missing section: ${section}"
    exit 1
  fi

  echo "OK: ${section}"
done

required_dirs=(
  "docs/assets/observability-sre"
  "docs/assets/security-governance"
  "docs/assets/backup-disaster-recovery"
  "docs/assets/secrets-management"
  "docs/assets/developer-portal"
)

echo
echo "Checking evidence directories..."

for dir in "${required_dirs[@]}"; do
  if [[ ! -d "${dir}" ]]; then
    echo "ERROR: missing directory: ${dir}"
    exit 1
  fi

  count="$(find "${dir}" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) | wc -l | tr -d ' ')"

  if [[ "${count}" == "0" ]]; then
    echo "ERROR: no image evidence found in ${dir}"
    exit 1
  fi

  echo "OK: ${dir} (${count} images)"
done

echo
echo "Checking documentation index reference..."

if ! grep -qF "[Evidence index](EVIDENCE_INDEX.md)" docs/DOCUMENTATION_INDEX.md; then
  echo "ERROR: docs/DOCUMENTATION_INDEX.md does not reference EVIDENCE_INDEX.md"
  exit 1
fi

echo "OK: docs/DOCUMENTATION_INDEX.md references EVIDENCE_INDEX.md"

echo
echo "============================================================"
echo "Evidence index validated successfully."
echo "============================================================"
