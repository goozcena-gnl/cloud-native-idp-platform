# GHCR: container image registry

The `demo-grpc` image is published to the GitHub Container Registry (GHCR).

Published image:

```
ghcr.io/goozdu12/cloud-native-idp-platform/demo-grpc
```

## Publishing workflow

Workflow file: `.github/workflows/publish-demo-grpc.yml`

The workflow runs on:

- push to `main` when `services/demo-grpc/**`, `charts/demo-grpc/**`, or the
  workflow file itself changes;
- manual dispatch (`workflow_dispatch`).

## Authentication

The workflow uses `GITHUB_TOKEN` with:

```yaml
permissions:
  contents: read
  packages: write
```

No personal access token is stored in repository secrets.

## Tags

Each publish produces two tags:

| Tag | Value |
|-----|-------|
| `main` | always points to the latest build from `main` |
| `sha-<short>` | immutable tag for the exact commit (e.g. `sha-a3c1446`) |

## Current limitation

The Kubernetes deployment still uses the local image `demo-grpc:local` loaded
into kind. A later task will update the Helm values and ArgoCD Application to
use the GHCR image by digest or by SHA tag.

## Security notes

Do not store registry credentials in Git.

For production-grade supply chain security, future improvements should include:

- Trivy scan before publish;
- SBOM generation;
- image signing with Cosign;
- signature verification with Kyverno;
- immutable deployment by digest.
