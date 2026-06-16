#!/usr/bin/env bash

set -euo pipefail

REMOTE_NAME="${REMOTE_NAME:-origin}"

redact_remote_url() {
  local remote_url="$1"

  printf '%s\n' "${remote_url}" | sed -E \
    -e 's#(https?://)[^/@]+@#\1***@#' \
    -e 's#(https?://)[^/:]+:[^/@]+@#\1***:***@#'
}

normalize_github_remote_to_https() {
  local remote_url="$1"
  local normalized="${remote_url}"

  case "${remote_url}" in
    git@github.com:*)
      normalized="https://github.com/${remote_url#git@github.com:}"
      ;;
    ssh://git@github.com/*)
      normalized="https://github.com/${remote_url#ssh://git@github.com/}"
      ;;
    https://*@github.com/*)
      normalized="$(printf '%s\n' "${remote_url}" | sed -E 's#^https://[^/@]+@github.com/#https://github.com/#')"
      ;;
    http://github.com/*)
      normalized="https://${remote_url#http://}"
      ;;
  esac

  if [[ "${normalized}" =~ ^https://github\.com/[^/]+/[^/\.]+$ ]]; then
    normalized="${normalized}.git"
  fi

  printf '%s\n' "${normalized}"
}

github_repo_slug_from_url() {
  local repo_url="$1"
  local path=""

  case "${repo_url}" in
    https://github.com/*)
      path="${repo_url#https://github.com/}"
      path="${path%.git}"
      if [[ "${path}" == */* && "${path}" != */*/* ]]; then
        printf '%s\n' "${path}"
      fi
      ;;
  esac
}

echo "============================================================"
echo "GitOps repository access check"
echo "Remote: ${REMOTE_NAME}"
echo "============================================================"
echo

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is not installed or not in PATH."
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: this script must be run from inside a Git repository."
  exit 1
fi

if ! REMOTE_URL="$(git remote get-url "${REMOTE_NAME}" 2>/dev/null)"; then
  echo "ERROR: git remote '${REMOTE_NAME}' was not found."
  echo
  echo "Configured remotes:"
  git remote -v || true
  exit 1
fi

RECOMMENDED_REPO_URL="$(normalize_github_remote_to_https "${REMOTE_URL}")"
REDACTED_REMOTE_URL="$(redact_remote_url "${REMOTE_URL}")"
REDACTED_RECOMMENDED_REPO_URL="$(redact_remote_url "${RECOMMENDED_REPO_URL}")"
GITHUB_REPO_SLUG="$(github_repo_slug_from_url "${RECOMMENDED_REPO_URL}")"
CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || true)"
LATEST_COMMIT="$(git log -1 --oneline 2>/dev/null || true)"

echo "Detected git remote '${REMOTE_NAME}':"
echo "  ${REDACTED_REMOTE_URL}"
echo
echo "Recommended ArgoCD repoURL:"
echo "  ${REDACTED_RECOMMENDED_REPO_URL}"
echo

echo "Current branch:"
if [[ -n "${CURRENT_BRANCH}" ]]; then
  echo "  ${CURRENT_BRANCH}"
else
  echo "  Unable to determine current branch"
fi
echo

echo "Latest commit:"
if [[ -n "${LATEST_COMMIT}" ]]; then
  echo "  ${LATEST_COMMIT}"
else
  echo "  Unable to determine latest commit"
fi
echo

if [[ -n "${GITHUB_REPO_SLUG}" ]]; then
  echo "GitHub repository:"
  echo "  ${GITHUB_REPO_SLUG}"
else
  echo "GitHub repository:"
  echo "  Unable to infer owner/repo from the remote URL."
fi
echo

VISIBILITY="unknown"

if command -v gh >/dev/null 2>&1; then
  if gh auth status -h github.com >/dev/null 2>&1; then
    echo "GitHub CLI: authenticated"
    if [[ -n "${GITHUB_REPO_SLUG}" ]]; then
      REPO_METADATA="$(gh repo view "${GITHUB_REPO_SLUG}" \
        --json nameWithOwner,visibility,url,defaultBranchRef \
        --jq '"Repository: \(.nameWithOwner)\nVisibility: \(.visibility)\nURL: \(.url)\nDefault branch: \(.defaultBranchRef.name)"' 2>/dev/null || true)"
      VISIBILITY="$(printf '%s\n' "${REPO_METADATA}" | sed -n 's/^Visibility: //p')"
      if [[ -n "${VISIBILITY}" ]]; then
        echo "GitHub repository metadata:"
        printf '%s\n' "${REPO_METADATA}" | sed 's/^/  /'
      else
        VISIBILITY="unknown"
        echo "Repository visibility: unavailable from gh repo view"
      fi
    else
      echo "Repository visibility: unavailable without a GitHub owner/repo slug"
    fi
  else
    echo "GitHub CLI: installed but not authenticated for github.com"
    echo "Repository visibility: unavailable"
  fi
else
  echo "GitHub CLI: not installed or not in PATH"
  echo "Repository visibility: unavailable"
fi

echo
echo "ArgoCD implication:"
case "${VISIBILITY}" in
  PUBLIC)
    echo "  Public repository: ArgoCD can read this repoURL without Git credentials."
    ;;
  PRIVATE|INTERNAL)
    echo "  ${VISIBILITY} repository: ArgoCD will need Git credentials configured in the cluster."
    echo "  Do not commit usernames, passwords, tokens, deploy keys, or repo Secret manifests."
    ;;
  *)
    echo "  Visibility is unknown. Confirm whether the repository is public or private before creating ArgoCD Applications."
    echo "  If it is private, configure credentials later outside Git."
    ;;
esac

echo
echo "This script is read-only. It does not configure ArgoCD credentials."
echo "============================================================"