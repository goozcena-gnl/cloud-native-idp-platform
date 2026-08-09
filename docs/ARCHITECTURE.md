# Architecture Overview

This page is the concise entry point for the target and MVP boundaries. The
[Architecture and Capabilities Summary](ARCHITECTURE_AND_CAPABILITIES.md) is the
canonical technical reference for platform layers, GitOps delivery, validation,
local-first choices, and production improvements.

## Target architecture

The long-term target is an Internal Developer Platform composed of:

- Developer Control Plane: Backstage
- Integration and Delivery Plane: GitHub Actions and ArgoCD
- Kubernetes Execution Plane: Kubernetes, Helm, Cilium
- Security Plane: Trivy, Kyverno, Vault, Falco
- Observability Plane: OpenTelemetry, Prometheus, Loki, Tempo, Grafana
- Platform Services: Crossplane, OpenCost, Velero

## MVP architecture

The MVP focuses on:

- Local Kubernetes
- ArgoCD GitOps
- One Go gRPC microservice
- Helm deployment
- GitHub Actions CI
- Trivy scanning
- Basic observability
- Basic admission policies

## Architecture principle

Start simple, prove the platform loop, then add production-grade capabilities incrementally.

## Architecture decisions

The accepted decisions behind this architecture are indexed in the
[Architecture decisions](DOCUMENTATION_INDEX.md#architecture-decisions) section
of the documentation index.
