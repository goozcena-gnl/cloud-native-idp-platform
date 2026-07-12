# Final Release Checklist

## Goal

This checklist defines the final readiness criteria for the Cloud Native IDP Platform portfolio project.

It is intended to answer one question:

> Is this repository ready to be shown as a professional DevOps / Platform Engineering portfolio project?

## 1. Git and CI Readiness

### Required state

- Git working tree is clean.
- Local branch is up to date with `origin/main`.
- Latest GitHub Actions CI run is successful.
- No uncommitted generated files remain.

### Validation

```bash
git status
gh run list --workflow CI --limit 5
```

### Expected result

```text
nothing to commit, working tree clean
latest CI run: success
```

## 2. GitOps Readiness

### Required state

- Argo CD is running.
- All Argo CD applications are `Synced`.
- All Argo CD applications are `Healthy`.

### Validation

```bash
kubectl -n argocd get applications \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status' \
  | sort
```

### Expected result

```text
All applications: Synced / Healthy
```

## 3. Portfolio Documentation Readiness

### Required documentation

- `README.md`
- Portfolio overview
- Documentation index
- Evidence index
- Architecture and capabilities summary
- Milestones
- Observability documentation
- Security governance documentation
- Runtime operations documentation
- Developer experience documentation
- Backstage documentation

### Validation

```bash
./scripts/check-readme-portfolio.sh
./scripts/check-portfolio-package.sh
./scripts/check-evidence-index.sh
./scripts/check-architecture-summary.sh
```

### Expected result

```text
Portfolio README validated successfully.
Final portfolio package validated successfully.
Evidence index validated successfully.
Architecture and capabilities summary validated successfully.
```

## 4. Platform Capability Readiness

### Required capabilities

- Kubernetes platform foundation
- Argo CD GitOps
- Go gRPC reference service
- CI/CD
- Observability stack
- Alerts and SLO documentation
- Security governance
- NetworkPolicies
- Runtime security
- Cost visibility
- Backup and restore
- Secrets management
- Developer portal
- Backstage software template

### Validation

```bash
./scripts/check-final-platform.sh
```

### Expected result

```text
Final platform validation completed successfully.
```

## 5. Full Operational Validation

The full validation mode should pass when the local cluster and all supporting components are available.

### Validation

```bash
FULL_VALIDATION=true ./scripts/check-final-platform.sh
```

### Expected result

```text
Final platform validation completed successfully.
```

## 6. Evidence Readiness

### Required evidence folders

- `docs/assets/observability-sre/`
- `docs/assets/security-governance/`
- `docs/assets/backup-disaster-recovery/`
- `docs/assets/secrets-management/`
- `docs/assets/developer-portal/`

### Validation

```bash
./scripts/check-evidence-index.sh
```

### Expected result

```text
Evidence index validated successfully.
```

## 7. Interview Readiness

The project should be explainable through these topics:

- Why the platform exists
- How GitOps is structured
- How the demo service proves platform capabilities
- How metrics, logs, and traces are correlated
- How Kubernetes security is enforced
- How runtime detection is validated
- How backup and restore are tested
- How Vault Kubernetes authentication works
- How Backstage improves developer experience
- What is local-first
- What would change in production

### Reference document

```text
docs/ARCHITECTURE_AND_CAPABILITIES.md
```

## 8. Known Local-First Limitations

The project is considered ready even with the following documented local-first choices:

- `kind` instead of managed Kubernetes
- Local Docker images
- Local MinIO
- Vault dev mode
- Local Backstage image
- Simplified authentication
- Local port-forward access
- Backstage Kubernetes plugin disabled until proper cluster locator configuration is added

These choices are acceptable because they are explicitly documented and aligned with the local portfolio goal.

## 9. Final Release Criteria

The portfolio is considered ready when all commands pass:

```bash
git status
gh run list --workflow CI --limit 5

./scripts/check-readme-portfolio.sh
./scripts/check-portfolio-package.sh
./scripts/check-evidence-index.sh
./scripts/check-architecture-summary.sh
./scripts/check-final-platform.sh
FULL_VALIDATION=true ./scripts/check-final-platform.sh
```

## Final Status

When all validations pass, the repository is ready to be shown as a professional DevOps / Cloud / Platform Engineering portfolio project.