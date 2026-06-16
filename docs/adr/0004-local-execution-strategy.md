# ADR 0004: Local execution strategy

## Status

Accepted

## Context

The local development environment currently uses Windows with Git Bash/MSYS.

Detected tooling:

- Docker Desktop on Windows
- kubectl Windows binary
- Helm Windows binary
- kind Windows binary
- Go Windows binary
- Terraform Windows binary
- GitHub CLI Windows binary
- Ansible available through a WSL-backed setup

The repository may later use Linux-first workflows, but the MVP should match the current working environment to avoid unnecessary setup friction.

## Decision

The MVP will use a Windows/Git Bash-first workflow:

- Git Bash is the primary terminal for repository commands.
- Docker Desktop provides the container runtime.
- kind creates the local Kubernetes cluster using Docker Desktop.
- kubectl, Helm, Go, Terraform, and GitHub CLI use Windows binaries.
- Ansible is deferred to an advanced phase unless a Linux or VM-based target requires it.

## Consequences

Positive:

- Uses the tools already installed.
- Reduces setup time.
- Works well with Docker Desktop and kind on Windows.
- Keeps the MVP focused on Kubernetes, GitOps, CI, observability, and security.

Trade-offs:

- Some Linux-native scripts may need Git Bash compatibility.
- Volume mounts must be tested carefully.
- WSL and Windows path mixing must be avoided.
- Ansible will not be part of the MVP bootstrap.

## Security implications

No credentials or kubeconfig files should be committed.

The project must continue to exclude:

- kubeconfig files;
- Terraform state;
- `.env` files;
- cloud credentials;
- private keys;
- Vault tokens;
- GitHub tokens.
