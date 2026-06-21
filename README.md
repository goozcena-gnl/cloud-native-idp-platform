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

Current phase: GitOps foundation.

**Latest milestone (2026-06-17):** Platform namespaces are reconciled through
GitOps. ArgoCD runs locally against the private repository, with `idp-root` and
`platform-namespaces` both **Synced** and **Healthy**. Git is the source of
truth for namespace state.

See [docs/MILESTONES.md](docs/MILESTONES.md).

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

The MVP uses a temporary, short-lived PAT with repository read access only,
stored solely in a Kubernetes Secret and never committed to Git. The advanced
target is a read-only deploy key, a GitHub App, or a Vault-managed credential.
See [docs/security/GITHUB_TOKEN_STRATEGY.md](docs/security/GITHUB_TOKEN_STRATEGY.md).

After committing and pushing the ArgoCD bootstrap manifests, create the root
GitOps Application:

```bash
./scripts/bootstrap-argocd-apps.sh
```

Validate ArgoCD Applications:

```bash
./scripts/check-argocd-apps.sh
```

Access the UI locally via port-forward:

```bash
./scripts/argocd-port-forward.sh
# then open http://localhost:8081
```

Validated ArgoCD Applications:

```text
idp-root              Synced   Healthy
platform-namespaces   Synced   Healthy
demo-grpc             Synced   Healthy
```

See [docs/GITOPS.md](docs/GITOPS.md),
[docs/GITOPS_REPOSITORY.md](docs/GITOPS_REPOSITORY.md),
[docs/MILESTONES.md](docs/MILESTONES.md), and
[docs/security/GITHUB_TOKEN_STRATEGY.md](docs/security/GITHUB_TOKEN_STRATEGY.md).

## Go gRPC reference service

A minimal Go gRPC service is the first real application workload.

```bash
# Run the server (from services/demo-grpc):
go run ./cmd/server

# Healthcheck in a second terminal:
go run ./cmd/healthcheck -addr localhost:50051
```

Local integration test (build, start, healthcheck, stop):

```bash
./scripts/test-demo-grpc.sh
```

See [services/demo-grpc/README.md](services/demo-grpc/README.md).

### Container

Build and run the service as a minimal, non-root container image:

```bash
docker build -t demo-grpc:local services/demo-grpc
docker run -d --name demo-grpc -p 50052:50051 demo-grpc:local
```

Automated container test (build, run, healthcheck, inspect, clean up):

```bash
./scripts/test-demo-grpc-container.sh
```

See [docs/CONTAINERIZATION.md](docs/CONTAINERIZATION.md).

### Helm chart

Validate the Helm chart (lint + template + server-side dry-run):

```bash
./scripts/validate-demo-grpc-helm.sh
```

See [docs/HELM.md](docs/HELM.md).

### GitOps deployment

Load the local image into kind (required before ArgoCD can pull it):

```bash
./scripts/load-demo-grpc-kind-image.sh
```

After committing and pushing `platform/argocd/apps/demo-grpc-app.yaml`,
ArgoCD picks up the Application automatically via `idp-root`. Validate:

```bash
./scripts/check-demo-grpc-k8s.sh
```

## CI (GitHub Actions)

The CI workflow runs on every push and pull request to `main`.

It validates:

- Go tests and builds;
- Docker image build and non-root runtime user check;
- Helm lint and `helm template` rendering;
- rendered Kubernetes security settings (`runAsNonRoot`, `allowPrivilegeEscalation`,
  `readOnlyRootFilesystem`, seccomp `RuntimeDefault`, capabilities drop, gRPC probes).

See [docs/CI.md](docs/CI.md) and [.github/workflows/ci.yml](.github/workflows/ci.yml).

## DevSecOps (Trivy)

The `security` CI job scans for vulnerabilities, secrets, and
misconfigurations using [Trivy](https://trivy.dev/):

- filesystem and Go dependency CVEs;
- hardcoded secrets;
- Dockerfile misconfigurations;
- rendered Helm manifest Kubernetes config issues;
- Docker image OS and application CVEs.

Trivy is installed from the official GitHub release archive and pinned to a
specific version. `aquasecurity/trivy-action` is not used (supply-chain
advisory, March 2026).

Run locally (requires Trivy and Helm in `PATH`):

```bash
docker build -t demo-grpc:local services/demo-grpc
./scripts/security-scan.sh
```

See [docs/DEVSECOPS.md](docs/DEVSECOPS.md).

## Container registry (GHCR)

The `demo-grpc` image is published to GHCR on every push to `main` that
changes `services/demo-grpc/**`.

Published image:

```
ghcr.io/goozdu12/cloud-native-idp-platform/demo-grpc
```

Tags: `main` (latest build) and `sha-<short>` (immutable per-commit tag).

Authentication uses `GITHUB_TOKEN` — no personal access token is required.

See [docs/GHCR.md](docs/GHCR.md).

## Observability

The first observability stack uses `kube-prometheus-stack` (Prometheus Operator,
Prometheus, Grafana, kube-state-metrics, node-exporter, default dashboards and
rules), deployed by ArgoCD via the multi-source pattern:

```text
platform/argocd/apps/kube-prometheus-stack-app.yaml
```

Validate:

```bash
./scripts/check-observability-stack.sh
```

Access Grafana locally:

```bash
./scripts/grafana-port-forward.sh
# then open http://localhost:3000  (admin / admin)
```

See [docs/OBSERVABILITY.md](docs/OBSERVABILITY.md).

## Observability milestone

The platform now includes a GitOps-managed observability stack:

```text
kube-prometheus-stack
```

Validated components: Prometheus Operator, Prometheus, Grafana,
kube-state-metrics, node-exporter, Kubernetes dashboards.

Access Grafana locally:

```bash
./scripts/grafana-port-forward.sh
```

Grafana health check:

```bash
curl -i http://localhost:3000/api/health
```

## Application metrics

`demo-grpc` exposes Prometheus metrics on `/metrics`.

Validate Kubernetes scraping:

```bash
./scripts/check-demo-grpc-metrics.sh
```

## Application metrics scraping

`demo-grpc` exposes Prometheus metrics on `/metrics`.

Kubernetes scraping is configured with:

```text
ServiceMonitor apps/demo-grpc
```

Validate:

```bash
./scripts/check-demo-grpc-metrics.sh
```

Expected result:

```
Service /metrics endpoint OK.
Prometheus target discovery OK.
Prometheus scrape query OK.
```

## Custom application metrics

`demo-grpc` now exposes custom Prometheus metrics:

```text
demo_grpc_build_info
demo_grpc_grpc_requests_total
demo_grpc_grpc_request_duration_seconds
```

These metrics are scraped by Prometheus through the `apps/demo-grpc` ServiceMonitor.

Validate:

```bash
./scripts/check-demo-grpc-metrics.sh
```

## Grafana dashboard

A `demo-grpc` dashboard is provisioned via GitOps (ConfigMap + Grafana sidecar).

Panels: service info, goroutines, total requests, error rate, request rate, p50/p95 latency.

```bash
./scripts/grafana-port-forward.sh
# then open http://localhost:3000/d/demo-grpc
```

Validate provisioning:

```bash
./scripts/check-grafana-dashboard.sh
```

## Centralized logs

The platform includes centralized Kubernetes logging with:

```text
Grafana Alloy -> Loki -> Grafana
```

Validate the logs stack:

```bash
./scripts/check-loki-stack.sh
./scripts/check-demo-grpc-logs.sh
```

Example LogQL query:

```logql
{namespace="apps", container="demo-grpc"}
```

See [docs/OBSERVABILITY.md](docs/OBSERVABILITY.md).

## Structured application logs

`demo-grpc` emits structured JSON logs to stdout.
These logs are collected by Grafana Alloy and stored in Loki.

Validate:

```bash
./scripts/check-demo-grpc-logs.sh
```

Example LogQL query:

```logql
{namespace="apps", container="demo-grpc"} |= `"msg":"starting service"`
```

## Grafana logs dashboard

The platform includes a GitOps-provisioned Grafana dashboard for `demo-grpc` logs.

Validate it with:

```bash
./scripts/check-grafana-logs-dashboard.sh
```

Dashboard UID:

```
demo-grpc-logs
```

## Grafana logs dashboard variables

The `demo-grpc Logs` dashboard supports filtering by:

```text
namespace
pod
container
```

Main LogQL pattern:

```logql
{namespace="$namespace", pod=~"$pod", container=~"$container"}
```

Validate the dashboard and variables:

```bash
./scripts/check-grafana-logs-dashboard.sh
```

## Grafana SRE summary dashboard

The platform includes a GitOps-provisioned SRE summary dashboard for `demo-grpc`.

It combines:

```text
Prometheus metrics
Loki logs
```

Validate it with:

```bash
./scripts/check-grafana-sre-dashboard.sh
```

Dashboard UID:

```
demo-grpc-sre
```