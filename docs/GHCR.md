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

## GitOps deployment from GHCR

The ArgoCD Application `platform/argocd/apps/demo-grpc-app.yaml` deploys the
GHCR image:

```
ghcr.io/goozdu12/cloud-native-idp-platform/demo-grpc:main
```

Because `main` is a mutable tag, the Deployment uses `pullPolicy: Always`.

### Pull secret

The package is private, so the cluster needs a pull secret. Create it locally
without printing the token:

```bash
GITHUB_USERNAME=goozdu12 ./scripts/configure-ghcr-pull-secret.sh
```

This creates a `docker-registry` Secret named `ghcr-demo-grpc-pull` in the
`apps` namespace, referenced via `imagePullSecrets` in the Helm chart. The
Secret is not committed to Git.

Validate:

```bash
kubectl -n apps get secret ghcr-demo-grpc-pull
```

## Security notes

Do not store registry credentials in Git.

For production-grade supply chain security, future improvements should include:

- publish a public portfolio image; or
- use immutable `sha-*` tags; or
- deploy by digest; or
- manage registry credentials through Vault / External Secrets;
- Trivy scan before publish;
- SBOM generation;
- image signing with Cosign;
- signature verification with Kyverno.
