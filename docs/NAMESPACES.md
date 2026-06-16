# Platform Namespaces (Task 1.2)

This task creates the MVP namespaces for the local IDP from versioned YAML.
This is the pre-ArgoCD bootstrap step: namespaces are applied manually now,
and ArgoCD will later become the GitOps reconciler.

## Namespaces

| Namespace | Tier | Purpose |
|---|---|---|
| `argocd` | gitops | GitOps reconciler (installed later) |
| `platform-system` | platform | Core platform components (ingress, controllers) |
| `apps` | workloads | Application workloads (Go gRPC demo, etc.) |
| `observability` | observability | Metrics, logs, traces stack |
| `security` | security | Admission control and runtime security tooling |

All namespaces carry these labels:

- `app.kubernetes.io/part-of: idp-platform`
- `idp.platform/tier: <tier>`
- `idp.platform/managed-by: manual-bootstrap`

## Pod Security

Pod Security Admission (PSA) is intentionally not enforced yet.

The MVP does not immediately enforce strict PSA on all namespaces, because
components like ArgoCD, observability agents, and security tools may need
permissions, volumes, or runtime settings that are not compatible with
immediate `restricted` enforcement. We harden progressively instead of
breaking the platform early.

- No `enforce` label is set on any namespace during early bootstrap.
- Only the `apps` namespace sets `warn` and `audit` to `restricted`:

```
pod-security.kubernetes.io/warn=restricted
pod-security.kubernetes.io/audit=restricted
```

This gives early feedback about insecure workload configuration without
blocking development. Strict enforcement will be introduced later, after the
demo workload and platform services are hardened.

## GitOps transition

During pre-ArgoCD bootstrap, applying namespace manifests manually is
acceptable. After ArgoCD is installed, namespace changes should be reconciled
through GitOps rather than applied by hand.

## Apply the Namespaces

Run from the repository root:

```bash
./scripts/apply-platform-namespaces.sh
```

The script is idempotent: re-running it reconciles labels without recreating
namespaces.

## Validate

```bash
kubectl get namespaces -l app.kubernetes.io/part-of=idp-platform --show-labels
kubectl get namespace apps -o yaml | grep pod-security
```

Expected results:

- Namespaces `argocd`, `platform-system`, `apps`, `observability`, `security`
  all exist with `Active` status.
- All show the `idp-platform` part-of label.
- Only `apps` shows `pod-security.kubernetes.io/warn` and `audit` labels.

## Troubleshooting

### Context not found

If the script reports the context is missing:

```bash
kubectl config get-contexts
./scripts/create-kind-cluster.sh
```

### Namespace stuck Terminating

A namespace can hang in `Terminating` if it still holds finalizer-bound
resources. Inspect it:

```bash
kubectl get namespace <name> -o yaml
kubectl get all -n <name>
```

Remove the blocking resources, then let the namespace finish terminating.
Avoid force-removing finalizers unless you understand the consequences.

### Labels not updating

`kubectl apply` merges labels. If a label seems stale, confirm you edited
`platform/namespaces/namespaces.yaml` and re-applied:

```bash
kubectl apply -f platform/namespaces/namespaces.yaml
```

### Unexpected Pod Security warnings

Warnings on the `apps` namespace are expected and informational. They do not
block scheduling. They indicate a workload violates the `restricted` profile
and should be reviewed before enforcement is enabled later.

## Git commit message

```
feat(platform): add MVP namespaces with labels and apps Pod Security warn/audit

Add versioned namespaces (argocd, platform-system, apps, observability,
security) with platform labels. Apply restricted warn/audit Pod Security on
apps only; defer strict enforcement until platform charts are stable.
Add apply script and documentation.
```
