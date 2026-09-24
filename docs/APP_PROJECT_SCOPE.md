# Argo CD AppProject scope inventory

The `idp-platform` project manages the root Application and all 21 child
Applications in `platform/argocd/apps`. The root Application targets `argocd`.
Every Application uses the in-cluster API server. Its declared destinations
are limited to these namespaces:

| Destination | Applications |
|---|---|
| `apps` | demo-grpc, network-policies |
| `argocd` | idp-root, argocd-monitoring, platform-namespaces |
| `backstage` | backstage |
| `falco` | falco |
| `kyverno` | kyverno, kyverno-policies |
| `observability` | alloy-logs, grafana-dashboards, kube-prometheus-stack, loki, loki-monitoring, platform-alerts, platform-slo, tempo |
| `opencost` | opencost |
| `vault` | vault, vault-kubernetes-auth |
| `velero` | velero, velero-minio |

The AppProject also permits `kube-system`: rendering the pinned
`kube-prometheus-stack` chart with this repository's values creates five
component `Service` resources there (CoreDNS, controller manager, etcd, proxy,
and scheduler). No Application itself targets `kube-system`.

The `platform-namespaces` Application targets `argocd` but creates five
cluster-scoped `Namespace` objects: `argocd`, `platform-system`, `apps`,
`observability`, and `security`. Some chart Applications also use Argo CD's
`CreateNamespace=true` for their destination.

## Resource inventory

Repository-owned cluster-scoped resources include those `Namespace` objects,
the Vault Kubernetes auth `ClusterRoleBinding`, and the Kyverno `ClusterPolicy`.
Repository-owned namespaced resources include Applications, Deployments,
Services, Jobs, ServiceAccounts, ConfigMaps, NetworkPolicies,
ServiceMonitors, and PrometheusRules. `charts/demo-grpc` also renders a
Deployment, Service, and optional ServiceMonitor.

The following pinned upstream Helm charts are additional resource producers:

| Operator or component | Chart version | Destination |
|---|---|
| Grafana Alloy | `alloy` 1.10.0 | `observability` |
| Falco | `falco` 9.1.0 | `falco` |
| Prometheus Operator stack | `kube-prometheus-stack` 86.2.2 | `observability` |
| Kyverno | `kyverno` 3.8.1 | `kyverno` |
| Loki | `loki` 17.4.7 | `observability` |
| OpenCost | `opencost` 2.5.26 | `opencost` |
| Tempo | `tempo` 1.24.4 | `observability` |
| Vault and injector | `vault` 0.34.0 | `vault` |
| Velero | `velero` 12.1.0 | `velero` |

The Prometheus Operator stack supplies CRDs used by repository-owned
`ServiceMonitor` and `PrometheusRule` resources. Kyverno supplies the CRD used
by the repository-owned `ClusterPolicy`. Velero also installs CRDs. The
Kyverno Application explicitly accounts for `CustomResourceDefinition`,
`ValidatingWebhookConfiguration`, and `MutatingWebhookConfiguration` when
comparing resources. An offline Helm render of all nine pinned charts with
this repository's values and `--include-crds` found cluster RBAC, CRDs, and
webhook configurations, and confirmed their explicit resource namespaces.
This does not prove that a replacement resource allowlist will work through
an Argo CD sync in the live lab cluster.

The destination wildcard was removed because the Application destinations and
chart-created `kube-system` resources are known. Both resource wildcards remain
documented for this local lab: an allowlist inferred from offline manifests
alone could block operator installation, CRDs, RBAC, webhooks, or chart
upgrades. Before narrowing either resource list, compare the rendered resource
group/kind pairs with local manifests and validate an Argo CD sync against the
intended cluster. Revisit the scope when chart versions change.
