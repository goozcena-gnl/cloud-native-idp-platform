# Project Milestones

This document records significant, verifiable milestones in the build-out of
the Internal Developer Platform. Each milestone captures what was achieved,
what remains manual, and the relevant security posture at that point in time.

The tone is intentionally factual: a milestone is only listed once it has been
validated against the running cluster.

---

## Milestone: GitOps Reconciliation of Platform Namespaces

**Date:** 2026-06-17
**Phase:** GitOps foundation
**Status:** Achieved and validated

### Summary

The platform now reconciles its namespaces through GitOps. ArgoCD reads the
desired state from the Git repository and continuously enforces it on the local
kind cluster, replacing the earlier manual `kubectl apply` bootstrap path for
namespaces.

### What was achieved

- A local `kind` cluster (`idp-local`) is running.
- ArgoCD is installed via the `argo/argo-cd` Helm chart in the `argocd`
  namespace, exposed locally only (ClusterIP + `kubectl port-forward`).
- ArgoCD authenticates to the **private** GitHub repository using read
  credentials supplied through a Kubernetes `Secret`. No credentials are
  committed to Git.
- An app-of-apps layout is live:
  - AppProject `idp-platform`
  - Root Application `idp-root` — **Synced** and **Healthy**
  - Child Application `platform-namespaces` — **Synced** and **Healthy**
- Platform namespaces are now reconciled through GitOps from
  `platform/namespaces`, driven by the root Application reading
  `platform/argocd/apps`.
- Git is now the source of truth for namespace state. Drift is automatically
  corrected by ArgoCD (`prune` and `selfHeal` enabled).

### Reconciliation flow

```text
ArgoCD repository credential Secret
  -> idp-root Application
  -> platform/argocd/apps
  -> platform-namespaces Application
  -> platform/namespaces
```

### Validation evidence

```bash
./scripts/check-argocd-apps.sh
kubectl -n argocd get applications.argoproj.io idp-root platform-namespaces
kubectl get namespaces argocd platform-system apps observability security --show-labels
```

Expected:

- `idp-root`: `Synced` / `Healthy`
- `platform-namespaces`: `Synced` / `Healthy`
- The five platform namespaces exist with their managed labels.

### What is still manual

These steps remain intentionally manual for the MVP and are candidates for
automation in later phases:

- Cluster creation (`./scripts/create-kind-cluster.sh`).
- ArgoCD installation via Helm (`./scripts/install-argocd.sh`).
- One-time creation of the ArgoCD repository credential Secret
  (`./scripts/configure-argocd-private-repo.sh`).
- One-time bootstrap of the root Application
  (`./scripts/bootstrap-argocd-apps.sh`).
- Rotating and eventually replacing the temporary Personal Access Token (PAT).

After this one-time bootstrap, application and platform changes flow through
Git rather than manual `kubectl apply`.

### Security posture at this milestone

- ArgoCD is not publicly exposed (ClusterIP + port-forward only).
- The Git repository is private.
- Repository read access uses a **temporary PAT** stored only in a Kubernetes
  `Secret`. The token is **never committed to Git**.
- The PAT is a deliberate MVP shortcut. It must be **short-lived** and rotated.
- The advanced target credential strategy is a **read-only deploy key**, a
  **GitHub App**, or a **Vault-managed credential**.

See [security/GITHUB_TOKEN_STRATEGY.md](security/GITHUB_TOKEN_STRATEGY.md) for
the full credential strategy and migration path.

### Next steps

- Replace the PAT with a least-privilege, read-only credential
  (deploy key / GitHub App / Vault).
- Onboard the first real workload (Go gRPC reference service) as a GitOps
  child Application under `platform/argocd/apps/`.
- Expand the app-of-apps tree to cover observability and security components.

## Next milestone

Deploy the first real application workload through GitOps:

- a minimal Go gRPC service;
- a Dockerfile;
- a Helm chart;
- a GitOps ArgoCD Application for the service;
- validation through Kubernetes and ArgoCD.

---

## Milestone: Go gRPC workload deployed through GitOps and GHCR

**Date:** 2026-06-17
**Phase:** Go gRPC reference workload
**Status:** Achieved and validated

### Summary

The `demo-grpc` Go gRPC service is now fully wired through the supply chain:

```text
Go source code
  -> Docker image (distroless, nonroot)
  -> GHCR package (ghcr.io/goozdu12/cloud-native-idp-platform/demo-grpc:main)
  -> ArgoCD Application (platform/argocd/apps/demo-grpc-app.yaml)
  -> Helm chart (charts/demo-grpc)
  -> Kubernetes Deployment and Service (namespace: apps)
```

Current image:

```
ghcr.io/goozdu12/cloud-native-idp-platform/demo-grpc:main
```

### Validated state

```text
idp-root              Synced   Healthy
platform-namespaces   Synced   Healthy
demo-grpc             Synced   Healthy
```

### Security posture at this milestone

- Image runs as `nonroot:nonroot` (UID 65532), distroless base.
- All restricted Pod Security Standard fields are set in the Helm chart.
- GHCR pull secret is stored only as a Kubernetes `docker-registry` Secret,
  never committed to Git.
- CI pipeline validates Go tests, Docker image, Helm chart, and Trivy security
  scans on every push to `main`.

### Known limitation

The deployment currently uses the mutable `main` tag. A future improvement
should deploy by immutable `sha-*` tag or image digest.

### Next steps

- Switch to immutable SHA tag or image digest.
- Add Prometheus metrics endpoint to `demo-grpc`.
- Add observability: structured logging, distributed tracing.
- Onboard Kyverno admission policies.

---

## Milestone: Observability foundation

**Date:** 2026-06-18
**Phase:** Observability and security
**Status:** Achieved and validated

### Validated outcomes

- `kube-prometheus-stack` is deployed through ArgoCD.
- Prometheus Operator is running.
- Prometheus is running.
- Grafana is running.
- kube-state-metrics is running.
- node-exporter is running on the local kind nodes.
- Grafana is reachable through local port-forwarding.
- Grafana `/api/health` returns HTTP 200.
- Kubernetes dashboards are visible in Grafana.

### Current observability flow

```text
ArgoCD Application
  -> prometheus-community/kube-prometheus-stack Helm chart
  -> platform/helm-values/kube-prometheus-stack-values.yaml
  -> observability namespace
  -> Prometheus + Grafana + Kubernetes dashboards
```

### Local tuning

Grafana resources were increased for local kind stability because the default
MVP limits were too small for Grafana, dashboards, sidecars, and internal APIs.

### Known limitations

- Grafana uses local MVP credentials.
- Grafana has no persistent storage.
- Alertmanager is disabled.
- Application-level metrics for `demo-grpc` are not exposed yet.
- Logs and traces are not configured yet.

### Next steps

- Expose Prometheus metrics from `demo-grpc`.
- Create a ServiceMonitor for `demo-grpc`.
- Build a Grafana dashboard for `demo-grpc` gRPC request metrics.
</content>
</invoke>
