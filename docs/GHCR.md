# GHCR: container image registry

The `demo-grpc` image is published to the GitHub Container Registry (GHCR).

Published image:

```
ghcr.io/goozcena-gnl/cloud-native-idp-platform/demo-grpc
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
| `main` | mutable; updated only by a trusted default-branch publication |
| `sha-<full-commit>` | immutable tag emitted for every publication, including a maintainer dispatch |

The `main` tag is intentionally mutable for convenience. A non-default-branch
manual dispatch cannot move it; that validation path publishes only the full
commit-derived `sha-*` tag.

## Namespace migration evidence

The historical `goozdu12` target became unusable after the repository owner
changed. Post-merge workflow run `30702883740` authenticated and built the image
successfully, then failed while pushing with:

```text
denied: not_found: owner not found
```

Authenticated registry inventory returned 404 for the old path and 200 for the
current `goozcena-gnl` path. GitHub Packages identifies the current package as
private, linked to `goozcena-gnl/cloud-native-idp-platform`, so publication and
all runtime consumers use the repository-owner namespace.

A controlled branch publication (`30704056484`) validated the new target without
moving `main`. It published:

```text
ghcr.io/goozcena-gnl/cloud-native-idp-platform/demo-grpc:sha-39b20cec49939fd4e90dcd5aef74ee71ee22c800
```

The OCI index digest is:

```text
sha256:cb481413930b3e15521e418bfddde9835c132d01db219c77049c875d98d30e58
```

Authenticated reads of the index, Linux/amd64 child manifest, configuration
blob, and first layer all succeeded.

## GitOps deployment from GHCR

The ArgoCD Application `platform/argocd/apps/demo-grpc-app.yaml` deploys the
GHCR image:

```
ghcr.io/goozcena-gnl/cloud-native-idp-platform/demo-grpc:sha-39b20cec49939fd4e90dcd5aef74ee71ee22c800
```

The GitOps consumer is pinned to the verified full-SHA tag and uses
`pullPolicy: IfNotPresent`.

### Pull secret

The package is private, so the cluster needs a pull secret. Create it locally
without printing the token:

```bash
GITHUB_USERNAME=goozcena-gnl ./scripts/configure-ghcr-pull-secret.sh
```

This creates a `docker-registry` Secret named `ghcr-demo-grpc-pull` in the
`apps` namespace, referenced via `imagePullSecrets` in the Helm chart. The
Secret is not committed to Git.

Validate:

```bash
kubectl -n apps get secret ghcr-demo-grpc-pull
```

## Validate publication and consumption

After a trusted `main` publication, verify the workflow and package metadata,
then confirm the GitOps consumer references the intended immutable tag:

```bash
gh run list --workflow publish-demo-grpc.yml --branch main --limit 1
kubectl -n apps get deployment demo-grpc \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n apps rollout status deployment/demo-grpc
```

## Important limitation

The current deployment uses an immutable full-SHA tag. The `main` tag remains a
mutable convenience tag and must not be treated as a release identity.

Further production improvements should prefer:

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
