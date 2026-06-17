# DevSecOps: security scanning

Security scanning is integrated into the CI pipeline using
[Trivy](https://trivy.dev/), an open-source vulnerability and
misconfiguration scanner.

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
- allows version bumps with a single variable change.

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
- SARIF upload and GitHub code scanning integration;
- SBOM generation.

## Future improvements

Planned future improvements:

- pin GitHub Actions by commit SHA;
- publish SARIF reports to GitHub Security tab;
- generate SBOMs (SPDX or CycloneDX);
- sign images with Cosign;
- verify signatures with Kyverno;
- add dependency review on pull requests;
- add image scan for base image freshness.
