# Architecture

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
