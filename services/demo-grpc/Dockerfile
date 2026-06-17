# syntax=docker/dockerfile:1

# ── build stage ──────────────────────────────────────────────────────────────
FROM golang:1.26-alpine AS build

WORKDIR /src

# Cache module downloads first.
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source.
COPY . .

# Build static, stripped binaries (CGO disabled for a scratch/distroless runtime).
ENV CGO_ENABLED=0 GOOS=linux
RUN go build -trimpath -ldflags="-s -w" -o /out/server      ./cmd/server && \
    go build -trimpath -ldflags="-s -w" -o /out/healthcheck ./cmd/healthcheck

# ── runtime stage ────────────────────────────────────────────────────────────
# Distroless static: minimal, no shell, runs as non-root (uid 65532) by default.
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app

# Copy the binaries from the build stage.
COPY --from=build /out/server      /app/server
COPY --from=build /out/healthcheck /app/healthcheck

# Run as the non-root user provided by the distroless image.
USER nonroot:nonroot

EXPOSE 50051

# Container-native health check using the gRPC healthcheck client.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/app/healthcheck", "-addr", "localhost:50051", "-timeout", "2s"]

ENTRYPOINT ["/app/server"]
