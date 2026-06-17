# Containerization (Task 2.2)

This task containerizes the `demo-grpc` service and validates it locally with
Docker. No image is pushed, and no Kubernetes, Helm, ArgoCD, CI, or registry
integration is added yet.

## Goals

- Produce a small, secure container image for the Go gRPC service.
- Run the container locally and validate it with the gRPC health client.
- Keep the build reproducible and the runtime minimal.

## Design

| Aspect | Choice |
|---|---|
| Build | Multi-stage Docker build |
| Builder image | `golang:1.26-alpine` |
| Runtime image | `gcr.io/distroless/static-debian12:nonroot` |
| Binaries | `server` and `healthcheck`, static (`CGO_ENABLED=0`) |
| User | Non-root (`nonroot`, uid 65532) |
| Port | `50051` (exposed) |
| Health | Docker `HEALTHCHECK` using the `healthcheck` binary |

### Why a multi-stage build

The build stage compiles the Go binaries with the full toolchain. Only the
resulting static binaries are copied into the runtime stage, so the final image
contains no compiler, shell, or package manager. This reduces image size and
attack surface.

### Why distroless static + non-root

`gcr.io/distroless/static-debian12:nonroot` contains no shell and no package
manager, and it runs as a non-root user by default. Static binaries
(`CGO_ENABLED=0`) have no dynamic library dependencies, so they run on this
minimal base without a libc. This is a strong default security posture for a
future Kubernetes restricted Pod Security Standard.

### Why the healthcheck binary

The image ships a tiny `healthcheck` client that calls the standard gRPC
health service. The Docker `HEALTHCHECK` runs this binary inside the container.
Because the runtime image has no shell, an in-image binary is the correct way
to express a container-native health probe. The same binary will later back a
Kubernetes gRPC liveness/readiness probe.

## Build the image

From the repository root:

```bash
docker build -t demo-grpc:local services/demo-grpc
```

## Run the container

```bash
docker run -d --name demo-grpc -p 50052:50051 demo-grpc:local
```

This maps host port `50052` to the container's `50051`.

## Validate

Call the gRPC health client from the host (uses the local Go toolchain):

```bash
cd services/demo-grpc
go run ./cmd/healthcheck -addr localhost:50052
```

Expected output:

```
healthcheck OK: SERVING
```

Inspect the image and container:

```bash
docker image ls demo-grpc:local
docker inspect -f '{{.Config.User}}' demo-grpc        # non-root
docker inspect -f '{{.State.Health.Status}}' demo-grpc # healthy
docker logs demo-grpc
```

## Automated container test

A script builds the image, runs it on host port `50052`, runs the gRPC health
client, inspects the image and container (size, non-root user, exposed port,
Docker health status), and cleans up afterward:

```bash
./scripts/test-demo-grpc-container.sh
```

Override the host port:

```bash
HOST_PORT=50055 ./scripts/test-demo-grpc-container.sh
```

## Clean up

```bash
docker rm -f demo-grpc
docker image rm demo-grpc:local
```

## Security notes

- The container runs as a non-root user with no shell available.
- The runtime image has no package manager, reducing the attack surface.
- Binaries are static and stripped (`-ldflags="-s -w"`).
- The container does not contain the source code or Go build cache.
- The container does not contain any compiler, shell, or package manager.
- No secrets are baked into the image.
- No image is pushed at this stage; publishing to a registry is a later task.

## Future improvements

- Publish the image to GHCR via CI.
- Add a Helm chart and Kubernetes deployment.
- Add a Trivy image scan.
- Wire a Kubernetes gRPC health probe to the same `healthcheck` logic.
- Deploy through ArgoCD as a GitOps child Application.
