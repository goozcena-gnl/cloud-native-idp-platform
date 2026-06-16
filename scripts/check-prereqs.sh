#!/usr/bin/env bash

set -uo pipefail

TOOLS=(git docker kubectl helm kind go terraform ansible gh)
WARNINGS=0

section() {
  printf '\n== %s ==\n' "$1"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  printf 'WARN: %s\n' "$1"
}

run_limited() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 10s "$@" 2>&1
  else
    "$@" 2>&1
  fi
}

tool_path() {
  command -v "$1" 2>/dev/null || true
}

first_line() {
  sed -n '1p'
}

detect_environment() {
  local kernel shell_name environment
  kernel="$(uname -s 2>/dev/null || echo unknown)"
  shell_name="${SHELL:-unknown}"
  environment="Linux/macOS shell"

  case "$kernel" in
    MINGW*|MSYS*|CYGWIN*) environment="Git Bash / MSYS on Windows" ;;
    Linux*)
      if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null || [[ -n "${WSL_INTEROP:-}" ]]; then
        environment="WSL2/Linux on Windows"
      fi
      ;;
    Darwin*) environment="macOS shell" ;;
  esac

  printf 'Detected environment: %s\n' "$environment"
  printf 'Kernel: %s\n' "$kernel"
  printf 'Shell: %s\n' "$shell_name"
  printf 'PWD: %s\n' "$(pwd)"
}

version_command() {
  case "$1" in
    git) echo "git --version" ;;
    docker) echo "docker --version" ;;
    kubectl) echo "kubectl version --client" ;;
    helm) echo "helm version --short" ;;
    kind) echo "kind version" ;;
    go) echo "go version" ;;
    terraform) echo "terraform version" ;;
    ansible) echo "ansible --version" ;;
    gh) echo "gh --version" ;;
  esac
}

check_tool() {
  local tool path command output status
  tool="$1"
  path="$(tool_path "$tool")"

  printf '\n[%s]\n' "$tool"

  if [[ -z "$path" ]]; then
    warn "$tool is missing from PATH"
    return
  fi

  printf 'Path: %s\n' "$path"

  if [[ -f /proc/version ]] && grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
    if [[ "$path" == /mnt/c/* || "$path" == *.exe ]]; then
      warn "$tool appears to resolve to a Windows binary from WSL: $path"
    fi
  fi

  case "$(uname -s 2>/dev/null || true)" in
    MINGW*|MSYS*|CYGWIN*)
      if [[ "$path" == *AppData/Local/Packages/PythonSoftwareFoundation* && "$tool" == ansible ]]; then
        warn "native Windows Ansible detected; prefer WSL-backed Ansible for control-node usage"
      fi
      ;;
  esac

  command="$(version_command "$tool")"
  output="$(run_limited bash -lc "$command" 2>&1)"
  status=$?

  if [[ $status -ne 0 ]]; then
    warn "$tool version command failed: $command"
    printf '%s\n' "$output" | first_line
    return
  fi

  if [[ "$tool" == ansible || "$tool" == gh || "$tool" == terraform ]]; then
    printf '%s\n' "$output" | sed -n '1,4p'
  else
    printf '%s\n' "$output" | first_line
  fi
}

check_docker_runtime() {
  section "Docker Runtime"

  if ! command -v docker >/dev/null 2>&1; then
    warn "docker is missing; daemon checks skipped"
    return
  fi

  printf 'Docker binary: %s\n' "$(tool_path docker)"

  local context_output context_status info_output info_status
  context_output="$(run_limited docker context show 2>&1)"
  context_status=$?
  if [[ $context_status -eq 0 ]]; then
    printf 'Docker context: %s\n' "$context_output"
  else
    warn "could not read Docker context"
    printf '%s\n' "$context_output" | first_line
  fi

  info_output="$(run_limited docker info --format '{{.ServerVersion}}' 2>&1)"
  info_status=$?
  if [[ $info_status -eq 0 && -n "$info_output" ]]; then
    printf 'Docker daemon: available\n'
    printf 'Docker server version: %s\n' "$info_output"
  else
    warn "Docker daemon is not reachable; start Docker Desktop or your configured daemon"
    printf '%s\n' "$info_output" | first_line
  fi
}

main() {
  section "Environment"
  detect_environment

  section "Tools"
  for tool in "${TOOLS[@]}"; do
    check_tool "$tool"
  done

  check_docker_runtime

  section "Summary"
  if [[ $WARNINGS -eq 0 ]]; then
    printf 'All prerequisite checks passed.\n'
    exit 0
  fi

  printf 'Completed with %d warning(s). Review the messages above.\n' "$WARNINGS"
  exit 1
}

main "$@"
