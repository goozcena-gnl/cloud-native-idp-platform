// Command server starts the demo-grpc gRPC server.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"syscall"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"

	"github.com/goozdu12/cloud-native-idp-platform/services/demo-grpc/internal/config"
)

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))

	cfg := config.Load()

	logger.Info("starting",
		"service", cfg.ServiceName,
		"version", cfg.AppVersion,
		"port", cfg.GRPCPort,
	)

	lis, err := net.Listen("tcp", fmt.Sprintf(":%s", cfg.GRPCPort))
	if err != nil {
		logger.Error("failed to listen", "err", err)
		os.Exit(1)
	}

	srv := grpc.NewServer()

	// Register the standard gRPC health service.
	healthSvc := health.NewServer()
	healthpb.RegisterHealthServer(srv, healthSvc)
	healthSvc.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)

	// Enable gRPC server reflection for tooling such as grpcurl.
	reflection.Register(srv)

	// Handle shutdown signals.
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)

	go func() {
		logger.Info("gRPC server listening", "addr", lis.Addr().String())
		if err := srv.Serve(lis); err != nil {
			logger.Error("serve error", "err", err)
		}
	}()

	sig := <-quit
	logger.Info("shutdown signal received", "signal", sig)

	// Mark the server as not serving before stopping, so in-flight health
	// checks from load balancers or readiness probes drain gracefully.
	healthSvc.SetServingStatus("", healthpb.HealthCheckResponse_NOT_SERVING)

	// Give in-flight RPCs up to 10 seconds to complete.
	stopped := make(chan struct{})
	go func() {
		srv.GracefulStop()
		close(stopped)
	}()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	select {
	case <-stopped:
		logger.Info("graceful shutdown complete")
	case <-ctx.Done():
		logger.Warn("graceful shutdown timed out, forcing stop")
		srv.Stop()
	}
}
