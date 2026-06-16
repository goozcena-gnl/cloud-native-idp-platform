# Local Kubernetes Cluster (Phase 1.1)

This phase creates a single reliable local Kubernetes cluster using `kind` and
Docker Desktop. It does not install ArgoCD, Cilium, or any other add-ons yet.

## Runtime model

| Component | Choice |
|---|---|
| Container runtime | Docker Desktop |
| Kubernetes runtime | kind |
| Shell | Git Bash |
| Cluster type | Local development |
| Initial CNI | kind default networking |
| Future CNI | Cilium, introduced later intentionally |

## Create the cluster

```bash
./scripts/create-kind-cluster.sh
```

## Validate the cluster

```bash
kubectl config current-context
kubectl get nodes -o wide
kubectl get pods -A
```

Expected context:

```
kind-idp-local
```

Expected nodes:

```
idp-local-control-plane
idp-local-worker
```

Both nodes should eventually show:

```
Ready
```

## Delete the cluster

```bash
./scripts/delete-kind-cluster.sh
```

## Port mappings

The cluster reserves host ports for future ingress demos:

| Host port | Cluster NodePort | Purpose |
|---|---|---|
| 18080 | 30080 | Future HTTP ingress demo |
| 18443 | 30443 | Future HTTPS ingress demo |

We avoid common ports like `80`, `443`, `8080`, and `8443` to reduce Windows
port conflicts.

## Security notes

This is a local development cluster.

Do not commit:

- kubeconfig files;
- generated credentials;
- Kubernetes Secrets;
- cloud credentials;
- Vault tokens;
- private keys.

Do not expose sensitive services through local port mappings.

## Troubleshooting

### Docker daemon is not reachable

Start Docker Desktop and retry:

```bash
docker info
```

### Port already allocated

If kind fails because port `18080` or `18443` is already used, edit:

```
platform/bootstrap/kind-config.yaml
```

Then retry cluster creation.

### kubectl points to the wrong cluster

Run:

```bash
kubectl config get-contexts
kubectl config use-context kind-idp-local
```

### Nodes stay NotReady

Check system pods:

```bash
kubectl get pods -A
kubectl describe node idp-local-control-plane
```

If the cluster is broken, delete and recreate it:

```bash
./scripts/delete-kind-cluster.sh
./scripts/create-kind-cluster.sh
```
