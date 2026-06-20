// Command server starts the demo-grpc gRPC server and Prometheus metrics server.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/goozdu12/cloud-native-idp-platform/services/demo-grpc/internal/config"
	"github.com/goozdu12/cloud-native-idp-platform/services/demo-grpc/internal/telemetry"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	cfg := config.Load()

	serverMetrics := telemetry.NewServerMetrics(cfg.ServiceName, cfg.AppVersion)

	grpcServer, healthSvc, lis := newGRPCServer(logger, cfg, serverMetrics)
	metricsServer := newMetricsServer(cfg)

	go serveGRPC(logger, grpcServer, lis, cfg)
	go serveMetrics(logger, metricsServer, cfg)

	waitForShutdown(logger, grpcServer, healthSvc, metricsServer)
}

func newGRPCServer(logger *slog.Logger, cfg *config.Config, serverMetrics *telemetry.ServerMetrics) (*grpc.Server, *health.Server, net.Listener) {
	address := net.JoinHostPort("", cfg.GRPCPort)
	lis, err := net.Listen("tcp", address)
	if err != nil {
		logger.Error("failed to listen for gRPC", "address", address, "error", err)
		os.Exit(1)
	}

	srv := grpc.NewServer(
		grpc.UnaryInterceptor(serverMetrics.UnaryServerInterceptor()),
	)
	healthSvc := health.NewServer()
	healthSvc.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(srv, healthSvc)
	reflection.Register(srv)

	return srv, healthSvc, lis
}

func newMetricsServer(cfg *config.Config) *http.Server {
	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())
	return &http.Server{
		Addr:              net.JoinHostPort("", cfg.MetricsPort),
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}
}

func serveGRPC(logger *slog.Logger, srv *grpc.Server, lis net.Listener, cfg *config.Config) {
	logger.Info("starting service",
		"service", cfg.ServiceName,
		"version", cfg.AppVersion,
		"grpc_port", cfg.GRPCPort,
	)
	if err := srv.Serve(lis); err != nil && !errors.Is(err, grpc.ErrServerStopped) {
		logger.Error("gRPC server failed", "error", err)
		os.Exit(1)
	}
}

func serveMetrics(logger *slog.Logger, metricsServer *http.Server, cfg *config.Config) {
	logger.Info("starting metrics server",
		"service", cfg.ServiceName,
		"version", cfg.AppVersion,
		"metrics_port", cfg.MetricsPort,
		"path", "/metrics",
	)
	if err := metricsServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		logger.Error("metrics server failed", "error", err)
		os.Exit(1)
	}
}

func waitForShutdown(
	logger *slog.Logger,
	srv *grpc.Server,
	healthSvc *health.Server,
	metricsServer *http.Server,
) {
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)
	<-quit

	logger.Info("shutdown signal received")
	healthSvc.SetServingStatus("", healthpb.HealthCheckResponse_NOT_SERVING)

	stopped := make(chan struct{})
	go func() {
		srv.GracefulStop()
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := metricsServer.Shutdown(ctx); err != nil {
			logger.Warn("metrics server shutdown failed", "error", err)
		}
		close(stopped)
	}()

	select {
	case <-stopped:
		logger.Info("servers stopped gracefully")
	case <-time.After(15 * time.Second):
		logger.Warn("graceful shutdown timed out; forcing stop")
		srv.Stop()
	}
}
