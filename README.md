# Cloud-Native Internal Developer Platform

A local-first, production-inspired DevOps / Platform Engineering portfolio project.

## Goal

Build a reproducible Internal Developer Platform demonstrating:

- Kubernetes-based workload orchestration
- GitOps delivery with ArgoCD
- Go gRPC microservices
- CI/CD with GitHub Actions
- Container and IaC security scanning
- Observability with metrics, logs, and traces
- Admission control and runtime security
- Secrets management
- Cost visibility
- Backup and recovery
- Developer self-service with Backstage

## Strategy

This project is implemented progressively:

1. Local-first MVP
2. GitOps foundation
3. Go gRPC reference workload
4. Observability and security
5. Advanced IDP capabilities

## Cost warning

The first version is designed to run locally where possible.  
Cloud resources are optional and may generate costs.

## Status

Current phase: Phase 0 — Project foundation.

## Local environment

Before creating local Kubernetes resources, verify the workstation prerequisites:

```bash
bash scripts/check-prereqs.sh
```

For PowerShell users:

```powershell
.\scripts\check-prereqs.ps1
```

See [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md).

## Local execution strategy

The MVP uses a Windows/Git Bash-first workflow with Docker Desktop and kind.

See:

- [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md)
- [`docs/adr/0004-local-execution-strategy.md`](docs/adr/0004-local-execution-strategy.md)

Ansible is deferred to an advanced phase unless Linux host configuration becomes necessary.

## Local Kubernetes cluster

Create it:

```bash
./scripts/create-kind-cluster.sh
```

Validate it:

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

Delete it:

```bash
./scripts/delete-kind-cluster.sh
```

See [docs/LOCAL_CLUSTER.md](docs/LOCAL_CLUSTER.md).

## Platform namespaces

Apply the MVP namespaces:

```bash
./scripts/apply-platform-namespaces.sh
```

Validate:

```bash
kubectl get namespaces argocd platform-system apps observability security --show-labels
```

See [docs/NAMESPACES.md](docs/NAMESPACES.md).

## GitOps (ArgoCD)

Install ArgoCD (local, private, ClusterIP only):

```bash
./scripts/install-argocd.sh
```

Check the Git repository URL and visibility before creating ArgoCD Applications:

```bash
./scripts/check-gitops-repo.sh
```

The preferred MVP model is a public GitHub repository with an HTTPS `repoURL`
and no committed credentials.

For a private GitOps repository, configure local ArgoCD repository access:

```bash
./scripts/configure-argocd-private-repo.sh
```

Validate without printing the token:

```bash
./scripts/check-argocd-repo-secret.sh
```

Access the UI locally via port-forward:

```bash
./scripts/argocd-port-forward.sh
# then open http://localhost:8081
```

See [docs/GITOPS.md](docs/GITOPS.md) and
[docs/GITOPS_REPOSITORY.md](docs/GITOPS_REPOSITORY.md).
