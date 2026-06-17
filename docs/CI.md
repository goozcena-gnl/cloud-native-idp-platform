# CI Pipeline (GitHub Actions)

This document describes the GitHub Actions CI workflow for the
`cloud-native-idp-platform` repository.

Workflow file: `.github/workflows/ci.yml`

## Triggers

- Push to `main`
- Pull request targeting `main`

Concurrent runs for the same ref are cancelled (`concurrency: cancel-in-progress: true`).

## Jobs

### Go test and build

Validates the `services/demo-grpc` Go module:

- downloads dependencies;
- verifies `go.mod` and `go.sum` are tidy (fails if out of sync);
- checks formatting with `gofmt`;
- runs unit tests (`go test ./...`);
- builds the server binary;
- builds the healthcheck binary.

### Docker build

Depends on the `go` job. Builds the `demo-grpc` image from:

```text
services/demo-grpc/Dockerfile
```

The image is not pushed to a registry. CI verifies that the image does not run
as root by inspecting `Config.User`.

### Helm chart validation

Depends on the `go` job. Validates `charts/demo-grpc` by running:

- `helm lint`;
- `helm template` (renders to a temp file);
- rendered security assertions: `runAsNonRoot`, `allowPrivilegeEscalation: false`,
  `readOnlyRootFilesystem: true`, `RuntimeDefault` seccomp, capabilities `drop`
  including an explicit `- ALL`, `readinessProbe`, `livenessProbe`, native
  `grpc:` probe.

### Trivy security scan

Depends on both `docker` and `helm`. Installs Trivy CLI from the official
GitHub release archive (pinned to `v0.69.3`) and runs four scans:

- **filesystem** — GO dependency CVEs, hardcoded secrets, Dockerfile misconfigurations;
- **Helm config** — Kubernetes security issues in rendered manifests;
- **image** — OS and application CVEs in the built Docker image.

`aquasecurity/trivy-action` is not used (supply-chain advisory, March 2026).
See [docs/DEVSECOPS.md](DEVSECOPS.md) for full rationale.

## Security model

The workflow uses the minimum permission set:

```yaml
permissions:
  contents: read
```

This follows least privilege: the workflow only reads repository contents; it
does not write, create releases, or push packages.

The `security` job also explicitly declares `permissions: contents: read` to
be self-documenting.

## Job dependency graph

```text
go
├── docker    (needs: go)
├── helm      (needs: go)
└── security  (needs: docker, helm)
```

`docker` and `helm` run in parallel after `go` passes. `security` runs after
both complete.

## Current limitations

This workflow does not yet:

- push images to GHCR;
- update GitOps image tags in the repository;
- run integration tests inside a kind cluster;
- publish SARIF reports to GitHub Security tab;
- generate SBOMs;
- sign images.

These will be added progressively as the project matures.
