# Evidence Index

This page centralizes the main visual evidence for the Cloud Native IDP Platform portfolio project.

The project uses three evidence layers:

1. ArgoCD application state: `Synced` and `Healthy`.
2. Executable validation scripts under `scripts/`.
3. Screenshots and visual evidence under `docs/assets/`.

## Final validation

The final platform validation entry point is:

```bash
./scripts/check-final-platform.sh
```

Full operational validation:

```bash
FULL_VALIDATION=true ./scripts/check-final-platform.sh
```

Expected result:

```text
Final platform validation completed successfully.
```

## Observability / SRE

- [01 argocd apps synced healthy](assets/observability-sre/01-argocd-apps-synced-healthy.png)
- [02 grafana sre overview](assets/observability-sre/02-grafana-sre-overview.png)
- [03 grafana sre loki metrics](assets/observability-sre/03-grafana-sre-loki-metrics.png)
- [04 prometheus availability rules](assets/observability-sre/04-prometheus-availability-rules.png)
- [05 prometheus gitops rules](assets/observability-sre/05-prometheus-gitops-rules.png)
- [06 github actions ci green](assets/observability-sre/06-github-actions-ci-green.png)
- [07 alertmanager ui](assets/observability-sre/07-alertmanager-ui.png)
- [08 alertmanager status receivers](assets/observability-sre/08-alertmanager-status-receivers.png)
- [09 runbooks documentation](assets/observability-sre/09-runbooks-documentation.png)
- [10 grafana tempo explore traces](assets/observability-sre/10-grafana-tempo-explore-traces.png)
- [11 grafana tempo trace detail](assets/observability-sre/11-grafana-tempo-trace-detail.png)
- [12 tempo api trace search](assets/observability-sre/12-tempo-api-trace-search.png)
- [13 grafana sre tempo panels](assets/observability-sre/13-grafana-sre-tempo-panels.png)
- [14 grafana sre slo panels](assets/observability-sre/14-grafana-sre-slo-panels.png)
- [20 log trace correlation script](assets/observability-sre/20-log-trace-correlation-script.png)
- [21 grafana loki traceid link](assets/observability-sre/21-grafana-loki-traceid-link.png)
- [22 grafana loki to tempo split view](assets/observability-sre/22-grafana-loki-to-tempo-split-view.png)
- [23 grafana loki datasource derivedfields api](assets/observability-sre/23-grafana-loki-datasource-derivedfields-api.png)

## Security Governance

- [01 demo grpc security baseline](assets/security-governance/01-demo-grpc-security-baseline.png)
- [02 kyverno stack validation](assets/security-governance/02-kyverno-stack-validation.png)
- [03 kyverno audit mode violations](assets/security-governance/03-kyverno-audit-mode-violations.png)
- [04 network policy baseline validation](assets/security-governance/04-network-policy-baseline-validation.png)
- [05 argocd security apps synced](assets/security-governance/05-argocd-security-apps-synced.png)

## Backup and Disaster Recovery

- [01 argocd velero apps synced](assets/backup-disaster-recovery/01-argocd-velero-apps-synced.png)
- [02 velero backupstoragelocation available](assets/backup-disaster-recovery/02-velero-backupstoragelocation-available.png)
- [03 velero backup restore script success](assets/backup-disaster-recovery/03-velero-backup-restore-script-success.png)
- [04 argocd velero resource tree](assets/backup-disaster-recovery/04-argocd-velero-resource-tree.png)
- [05 argocd velero minio resource tree](assets/backup-disaster-recovery/05-argocd-velero-minio-resource-tree.png)

## Secrets Management

- [01 argocd vault apps synced](assets/secrets-management/01-argocd-vault-apps-synced.png)
- [02 vault stack validation](assets/secrets-management/02-vault-stack-validation.png)
- [03 vault kubernetes auth validation](assets/secrets-management/03-vault-kubernetes-auth-validation.png)
- [04 argocd vault resource tree](assets/secrets-management/04-argocd-vault-resource-tree.png)
- [05 argocd vault kubernetes auth resource tree](assets/secrets-management/05-argocd-vault-kubernetes-auth-resource-tree.png)

## Developer Portal / Backstage

- [01 argocd backstage synced](assets/developer-portal/01-argocd-backstage-synced.png)
- [02 backstage stack validation](assets/developer-portal/02-backstage-stack-validation.png)
- [03 backstage ui home](assets/developer-portal/03-backstage-ui-home.png)
- [04 backstage demo grpc catalog entity](assets/developer-portal/04-backstage-demo-grpc-catalog-entity.png)
- [05 argocd backstage resource tree](assets/developer-portal/05-argocd-backstage-resource-tree.png)
- [06 backstage software template validation](assets/developer-portal/06-backstage-software-template-validation.png)
- [07 backstage go grpc software template](assets/developer-portal/07-backstage-go-grpc-software-template.png)

## Evidence folders

Main evidence folders:

```text
docs/assets/observability-sre/
docs/assets/security-governance/
docs/assets/backup-disaster-recovery/
docs/assets/secrets-management/
docs/assets/developer-portal/
```

## Related documentation

- [Portfolio project overview](PORTFOLIO_PROJECT_OVERVIEW.md)
- [Documentation index](DOCUMENTATION_INDEX.md)
- [Observability and SRE](PORTFOLIO_OBSERVABILITY_SRE.md)
- [Security governance](SECURITY_GOVERNANCE.md)
- [Runtime operations summary](PHASE_7_RUNTIME_OPERATIONS.md)
- [Developer Portal with Backstage](DEVELOPER_PORTAL_BACKSTAGE.md)
- [Platform Engineering and Developer Experience](PHASE_8_PLATFORM_ENGINEERING_DEVELOPER_EXPERIENCE.md)
