# DevSecOps: security scanning

Security scanning is integrated into the CI pipeline using
[Trivy](https://trivy.dev/), an open-source vulnerability and
misconfiguration scanner.

CI/CD pipeline security is separately enforced by
[Plumber](https://github.com/getplumber/plumber). The tools are complementary:

| Control | Purpose |
|---------|---------|
| Plumber | GitHub Actions configuration, action provenance, permissions, triggers, and CI/CD supply-chain policy |
| Trivy | Dependency, filesystem, rendered Kubernetes manifest, container-image, and lightweight secret scanning |
| GitHub secret scanning | Platform-side detection and push protection for supported secret patterns when enabled |

Plumber does not replace Trivy, CodeQL, dependency review, secret scanning,
artifact checksum verification, or branch protection.

## Plumber CI/CD security gate

Workflow file: `.github/workflows/plumber.yml`

The workflow runs a full repository scan for every pull request targeting
`main`, every push to `main`, and every manual dispatch. It deliberately has no
path filter: workflow behavior can depend on composite actions, configuration,
Dependabot settings, or scripts elsewhere in the repository.

The `Plumber gate` job:

- uses only `contents: read` and `security-events: write`;
- checks out without persisting Git credentials;
- installs Plumber `v0.4.26` through the official action, with checksum and
  SLSA/GitHub attestation verification enabled;
- extends Plumber's maintained default policy through `.plumber.yaml`;
- requires immutable 40-character commit pins for every external action,
  including GitHub-maintained actions;
- preserves Plumber's maintained trusted-publisher baseline without adding a
  repository-specific publisher wildcard;
- enforces score `A` with `soft-fail: false`;
- keeps external score publication disabled (`score-push: false`); and
- cancels obsolete runs and times out after 15 minutes.

Score publication remains disabled because it would disclose the repository
name and score to an external hosted badge service and would require
`id-token: write`. Neither is needed for the security gate.

### Reports

The job writes terminal findings and a GitHub job summary. It also generates:

- `plumber-report.json` — machine-readable findings and score;
- `plumber.sarif` — uploaded to the repository's Security / Code scanning view;
- `plumber-pbom.json` — Pipeline Bill of Materials;
- `plumber-cyclonedx-sbom.json` — CycloneDX pipeline inventory.

The files are bundled in the `plumber-security-reports` workflow artifact with
the official action's 30-day retention. Local copies are ignored by Git.

### Local validation

Install the current approved Plumber release from its official release page and
verify the published checksum before placing it in `PATH`. Then run from the
repository root:

```bash
plumber version
plumber config validate
plumber config resolve
plumber analyze \
  --config .plumber.yaml \
  --min-score A \
  --output plumber-report.json \
  --sarif plumber.sarif \
  --pbom plumber-pbom.json \
  --pbom-cyclonedx plumber-cyclonedx-sbom.json
```

Local workflow-content checks work without a token. `gh auth login` or a
`GH_TOKEN` enables repository metadata, branch-protection, archived-action,
ref-collision, and known-action-CVE checks. The Actions job uses its
least-privilege `GITHUB_TOKEN`; controls requiring repository Administration
read can report only the public protection state and abstain from detailed
force-push or code-owner settings.

### Baseline audit and disposition

The pre-change Plumber `v0.4.26` scan scored `E` (30/100). Plumber directly
reported ten `ISSUE-701` findings for mutable third-party action references and
one critical `ISSUE-501` finding because `main` was unprotected. Its first-run
default also counted nine mutable `actions/*` references as trusted-owner
exemptions; the repository overlay removes that exemption.

Manual supply-chain review found and remediated adjacent issues that the
baseline scan did not report:

- all 19 external references among 21 total action uses were mutable; every
  external reference is now pinned to a verified upstream 40-character commit
  with a release comment (the other two uses are local composite actions);
- checkout credentials persisted by default; all checkouts now use
  `persist-credentials: false`;
- the Trivy archive was executed without integrity verification; the installer
  now requires both the matching official checksum manifest and the
  repository-pinned SHA-256, and fails closed;
- `packages: write` applied to the whole publication workflow; it is now scoped
  to the single publishing job;
- the publishing job had no timeout; it now has a 30-minute timeout; and
- the immutable image tag used a shortened commit; it now uses the full commit
  while retaining the documented mutable `main` convenience tag.

Repository-level residual governance risks are not suppressed in Plumber:

- repository Actions policy currently allows all actions and does not itself
  require SHA pinning; an organization or repository policy should add that
  defense in depth;
- no CodeQL or dependency-review workflow is currently configured; adding them
  is outside this Plumber integration; and
- the GHCR target remains the historically documented personal namespace
  `goozdu12`. The package was not visible through the GitHub Packages API during
  this review, so authorization and repository linkage must be confirmed by the
  next trusted publish run. It was not changed blindly.

The Docker Buildx `type=gha` cache remains enabled. Pull requests cannot publish
an image, and the publishing workflow runs only from trusted `main` pushes or a
maintainer-triggered manual run. Cache behavior should still be reviewed if the
repository later introduces privileged pull-request triggers or cross-workflow
cache sharing.

As part of this rollout, `main` was protected with strict required status check
`Plumber gate`, administrator enforcement, and force-push and deletion disabled.
No review-count or linear-history policy was added. After that setting change,
the authenticated local scan passed all 21 enabled controls with score `A`
(100/100) and no findings. The only skipped control was
`workflowMustIncludeRequiredActions`, which is disabled in Plumber's maintained
default configuration.

## Why Trivy

Trivy scans multiple artifact types in a single tool:

| Scanner | What it checks |
|---------|----------------|
| `vuln` | Known CVEs in OS packages and language dependencies |
| `secret` | Hardcoded secrets and credentials |
| `misconfig` | Kubernetes and Dockerfile security misconfigurations |
| `config` | Rendered Kubernetes manifests (Helm output) |
| `image` | Docker image layers (OS + app dependencies) |

## Why not `aquasecurity/trivy-action`

A supply-chain incident in early 2026 affected the `aquasecurity/trivy-action`
and `setup-trivy` GitHub Actions. Security advisories recommended auditing
references to those actions.

This project installs the Trivy CLI directly from the official GitHub release
archive and pins it to a specific version (`0.69.3`). This approach:

- avoids transitive trust in third-party Actions;
- makes the installation transparent and auditable;
- verifies the archive against the official release checksum manifest and a
  repository-pinned SHA-256 before extraction; and
- requires version and checksum updates to be reviewed together.

## CI security job

The `security` CI job (`.github/workflows/ci.yml`) runs after `docker` and
`helm` complete successfully. It runs four scans:

### 1. Filesystem scan

```bash
trivy fs --scanners vuln,secret,misconfig --severity HIGH,CRITICAL --exit-code 1 .
```

Scans the repository root for:

- HIGH and CRITICAL CVEs in Go module dependencies;
- hardcoded secrets committed to the repository;
- Dockerfile misconfigurations.

### 2. Helm template render

```bash
helm template demo-grpc charts/demo-grpc --namespace apps > /tmp/demo-grpc-rendered.yaml
```

Renders the chart to a plain YAML file for static analysis.

### 3. Kubernetes config scan

```bash
trivy config --severity HIGH,CRITICAL --exit-code 1 /tmp/demo-grpc-rendered.yaml
```

Checks the rendered Kubernetes manifests against the NSA/CISA Kubernetes
Hardening Guide and CIS Kubernetes Benchmark.

### 4. Docker image scan

```bash
trivy image --severity HIGH,CRITICAL --exit-code 1 demo-grpc:local
```

Scans the built image for OS-level and application-level CVEs. Uses the same
image built by the `docker` CI job (loaded into the runner, not pushed).

## Local scan

To run the same scans locally, install Trivy first
([https://trivy.dev/latest/getting-started/installation/](https://trivy.dev/latest/getting-started/installation/)),
then run:

```bash
./scripts/security-scan.sh
```

If the local image `demo-grpc:local` is missing, the script builds it from
`services/demo-grpc` before running the Trivy image scan. To disable automatic
image build (fail instead):

```bash
BUILD_IMAGE_IF_MISSING=false ./scripts/security-scan.sh
```

The script checks for Trivy, Helm, and Docker in `PATH` and verifies the Docker
daemon is reachable, exiting with a clear error message if any prerequisite is
missing.

## Current limitations

This is intentionally strict and may require tuning later with:

- `.trivyignore` for accepted unfixed vulnerabilities;
- severity threshold adjustments;
- Trivy SARIF upload and Trivy SBOM generation (Plumber produces separate
  pipeline-focused SARIF, PBOM, and CycloneDX reports).

## Future improvements

Planned future improvements:

- add Trivy SARIF and container/software SBOMs (SPDX or CycloneDX);
- sign images with Cosign;
- verify signatures with Kyverno;
- add dependency review on pull requests;
- add image scan for base image freshness.
