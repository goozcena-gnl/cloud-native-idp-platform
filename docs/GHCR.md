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
jobs:
  publish:
    permissions:
      contents: read
      packages: write
```

`packages: write` is scoped only to the publishing job. No personal access
token is stored in repository secrets. The checkout step does not persist Git
credentials after fetching the repository.

## Tags

Each publish produces two tags:

| Tag | Value |
|-----|-------|
| `main` | always points to the latest build from `main` |
| `sha-<full-commit>` | immutable tag for the exact commit |

The `main` tag is intentionally mutable for the local-first MVP. Each trusted
publish also emits the full commit-derived `sha-*` tag so consumers can select
an immutable image reference.

The `goozdu12` namespace is retained because it is the historical personal GHCR
target used by this project, even though the repository now lives under
`goozcena-gnl`. Repository history and successful publish workflow runs through
2026-07-02 confirm that this target was intentional and previously usable.

Current verification did not confirm that the old namespace remains accessible:

- anonymous GHCR access was denied;
- authenticated registry requests for the old path's tag list and `main`
  manifest returned 404;
- the available credential recorded under the former `goozdu12` login now
  resolves through the GitHub API as `goozcena-gnl`; and
- GitHub package metadata exposes a private package named
  `cloud-native-idp-platform/demo-grpc`, linked to this repository, with its
  package URL under `goozcena-gnl`.

This is evidence of historical intent, but not evidence of current pull or push
access to `ghcr.io/goozdu12/...`. The reference is intentionally unchanged in
this security-gate PR. Before relying on the next publish, an owner must confirm
the namespace in GitHub Packages or migrate it in a separate, deliberate change
together with all deployment references and pull-secret documentation.

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

## Validated Kubernetes state

After deploying from GHCR, the following was validated against the
`kind-idp-local` cluster:

```text
demo-grpc Application: Synced / Healthy
Deployment: rolled out successfully
gRPC healthcheck: SERVING
```

## Important limitation

The current deployment uses the mutable tag `main`. This is acceptable for the
MVP, but production deployments should prefer:

- immutable commit SHA tags;
- image digests;
- signed images;
- admission verification.

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
