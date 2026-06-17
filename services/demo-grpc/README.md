# demo-grpc

A minimal Go gRPC service. This is the first reference workload for the
Internal Developer Platform.

## Purpose

- Validate the gRPC stack before adding a custom protobuf API.
- Provide a buildable, testable service that can later receive a Dockerfile,
  Helm chart, and GitOps ArgoCD Application.
- Demonstrate graceful shutdown, standard gRPC health service, and server
  reflection.

## Configuration

All configuration is supplied through environment variables.

| Variable       | Default      | Description                       |
|----------------|--------------|-----------------------------------|
| `GRPC_PORT`    | `50051`      | Port the gRPC server listens on   |
| `SERVICE_NAME` | `demo-grpc`  | Informational label in logs       |
| `APP_VERSION`  | `dev`        | Build version in logs             |

## Run locally

From `services/demo-grpc`:

```bash
go run ./cmd/server
```

Override the port:

```bash
GRPC_PORT=9090 go run ./cmd/server
```

## Healthcheck

In a second terminal, from `services/demo-grpc`:

```bash
go run ./cmd/healthcheck -addr localhost:50051
```

Expected output:

```
healthcheck OK: SERVING
```

Override address or timeout:

```bash
go run ./cmd/healthcheck -addr localhost:9090 -timeout 3s
```

## Test

Unit tests (config package):

```bash
go test ./...
```

Local integration test (build, start server, run healthcheck, stop):

```bash
# From the repository root:
./scripts/test-demo-grpc.sh
```

## Build

```bash
go build ./cmd/server
go build ./cmd/healthcheck
```

## Package structure

```text
services/demo-grpc/
├── cmd/
│   ├── server/       # gRPC server entry point
│   └── healthcheck/  # gRPC health check client
├── internal/
│   └── config/       # environment variable configuration
├── go.mod
├── Dockerfile
└── README.md
```

## Container

Build a minimal, non-root container image (multi-stage, distroless runtime):

```bash
# From the repository root:
docker build -t demo-grpc:local services/demo-grpc
```

Run it, mapping host port 50052 to the container's 50051:

```bash
docker run -d --name demo-grpc -p 50052:50051 demo-grpc:local
go run ./cmd/healthcheck -addr localhost:50052
```

Automated container test (build, run, healthcheck, inspect, clean up):

```bash
# From the repository root:
./scripts/test-demo-grpc-container.sh
```

The container test validates:

- image build;
- non-root runtime user;
- exposed gRPC service;
- host-side gRPC healthcheck (`healthcheck OK: SERVING`);
- Docker HEALTHCHECK status (`healthy`).

See [../../docs/CONTAINERIZATION.md](../../docs/CONTAINERIZATION.md).

## Future improvements

Planned additions:

- custom protobuf API;
- GHCR image publishing via CI;
- Helm chart;
- Kubernetes deployment;
- GitHub Actions CI;
- Trivy security scan;
- OpenTelemetry metrics and traces;
- ArgoCD GitOps Application.
