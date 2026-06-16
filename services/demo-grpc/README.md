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
└── README.md
```

## Future improvements

Planned additions:

- custom protobuf API;
- Dockerfile;
- Helm chart;
- Kubernetes deployment;
- GitHub Actions CI;
- Trivy security scan;
- OpenTelemetry metrics and traces;
- ArgoCD GitOps Application.
