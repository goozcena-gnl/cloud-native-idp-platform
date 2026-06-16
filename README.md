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
