# Helm Chart: demo-grpc (Task 2.3)

This task packages the `demo-grpc` Go gRPC service as a Helm chart and
validates it locally against the kind cluster. No ArgoCD deployment happens
at this stage.

## Design

| Aspect | Choice |
|---|---|
| Chart path | `charts/demo-grpc/` |
| Default namespace | `apps` |
| Default image | `demo-grpc:local` |
| Service type | `ClusterIP` |
| Port | `50051` |
| Runtime user | `65532` (nonroot, distroless default) |
| Pod Security | `restricted` (all fields set) |
| Health probes | gRPC via bundled `healthcheck` binary |

## Security defaults

The chart sets every field required by the Kubernetes restricted Pod Security
Standard. The `apps` namespace enforces `warn` and `audit` restricted PSA
labels, so a missing field will produce a warning. None are missing.

### Pod-level (`spec.securityContext`)

| Field | Value |
|---|---|
| `runAsNonRoot` | `true` |
| `runAsUser` | `65532` |
| `runAsGroup` | `65532` |
| `seccompProfile.type` | `RuntimeDefault` |

### Container-level (`spec.containers[].securityContext`)

| Field | Value |
|---|---|
| `allowPrivilegeEscalation` | `false` |
| `readOnlyRootFilesystem` | `true` |
| `capabilities.drop` | `["ALL"]` |

## Health probes

Both the liveness and readiness probes use native Kubernetes gRPC health
checks against the service port. The server registers the standard gRPC health
service, so Kubernetes can probe it directly:

```yaml
livenessProbe:
  grpc:
    port: 50051
```

This is a real gRPC health probe — not a TCP socket check. The bundled
`healthcheck` binary remains in the image for the Docker `HEALTHCHECK` and for
local testing.

## Resource requests and limits

| | CPU | Memory |
|---|---|---|
| Request | `50m` | `32Mi` |
| Limit | `200m` | `64Mi` |

## Chart structure

```text
charts/demo-grpc/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── service.yaml
    └── NOTES.txt
```

## Validate the chart (lint + template + dry-run)

```bash
./scripts/validate-demo-grpc-helm.sh
```

This runs, in order:

1. `helm lint` — checks the chart for structural issues.
2. Namespace existence check.
3. `helm template` — renders all manifests.
4. `kubectl apply --dry-run=client` — client-side schema validation.
5. `kubectl apply --dry-run=server` — validates rendered manifests against the
   live API server without creating any resources.
6. Rendered assertions — confirms the security context fields and gRPC probes
   are actually present in the output.

Override namespace or release name:

```bash
NAMESPACE=apps RELEASE=my-release ./scripts/validate-demo-grpc-helm.sh
```

## Manual validation steps

```bash
# Lint
helm lint charts/demo-grpc

# Render manifests
helm template demo-grpc charts/demo-grpc --namespace apps

# Server-side dry-run
helm template demo-grpc charts/demo-grpc --namespace apps \
  | kubectl apply --namespace apps --dry-run=server -f -
```

## Deploy locally (optional, not required by this task)

The chart is not deployed through ArgoCD at this stage. To install manually
for local exploration:

```bash
# The image must exist locally first:
docker build -t demo-grpc:local services/demo-grpc

helm install demo-grpc charts/demo-grpc \
  --namespace apps \
  --create-namespace

kubectl -n apps rollout status deployment/demo-grpc
kubectl -n apps port-forward svc/demo-grpc 50052:50051
# In a second terminal:
cd services/demo-grpc && go run ./cmd/healthcheck -addr localhost:50052
```

Uninstall:

```bash
helm -n apps uninstall demo-grpc
```

## Security notes

- The chart runs as a non-root user and drops all Linux capabilities.
- `readOnlyRootFilesystem: true` is compatible with the distroless runtime
  because the server binary writes no files.
- The seccomp `RuntimeDefault` profile satisfies both the restricted PSA and
  the runtime default policy enforcement.
- No image is pushed to a registry at this stage. Image publishing to GHCR
  via CI is a later task.

## Future improvements

- GitOps deployment via ArgoCD (child Application under `platform/argocd/apps/`).
- Image published to GHCR with a SHA-based tag.
- GitHub Actions CI running `helm lint` and `helm template` on every PR.
- Trivy scan of the chart and image.
- Kyverno policy validation.

## GitOps deployment

The `demo-grpc` chart is deployed by ArgoCD through:

```text
platform/argocd/apps/demo-grpc-app.yaml
```

For the local MVP, the image is `demo-grpc:local` and must be loaded into
kind before ArgoCD deploys the workload:

```bash
./scripts/load-demo-grpc-kind-image.sh
```

See [GITOPS.md](GITOPS.md) for the full GitOps deployment flow.
