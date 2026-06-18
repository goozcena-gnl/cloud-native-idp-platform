// Package telemetry registers and exposes custom Prometheus metrics for demo-grpc.
package telemetry

import (
	"context"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/status"
)

// ServerMetrics holds the custom Prometheus metrics for the gRPC server.
type ServerMetrics struct {
	serviceName     string
	buildInfo       *prometheus.GaugeVec
	requestsTotal   *prometheus.CounterVec
	requestDuration *prometheus.HistogramVec
}

// NewServerMetrics creates, registers, and returns ServerMetrics.
// It sets the build_info gauge immediately so the metric is present at startup.
func NewServerMetrics(serviceName, version string) *ServerMetrics {
	m := &ServerMetrics{
		serviceName: serviceName,
		buildInfo: prometheus.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "demo_grpc_build_info",
				Help: "Build and version information for demo-grpc.",
			},
			[]string{"service", "version"},
		),
		requestsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "demo_grpc_grpc_requests_total",
				Help: "Total number of gRPC requests handled by demo-grpc.",
			},
			[]string{"service", "method", "code"},
		),
		requestDuration: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "demo_grpc_grpc_request_duration_seconds",
				Help:    "Duration of gRPC requests handled by demo-grpc.",
				Buckets: prometheus.DefBuckets,
			},
			[]string{"service", "method", "code"},
		),
	}
	prometheus.MustRegister(
		m.buildInfo,
		m.requestsTotal,
		m.requestDuration,
	)
	m.buildInfo.WithLabelValues(serviceName, version).Set(1)
	return m
}

// UnaryServerInterceptor returns a gRPC unary interceptor that records
// request counts and durations for every RPC handled by the server.
func (m *ServerMetrics) UnaryServerInterceptor() grpc.UnaryServerInterceptor {
	return func(
		ctx context.Context,
		req any,
		info *grpc.UnaryServerInfo,
		handler grpc.UnaryHandler,
	) (any, error) {
		start := time.Now()
		resp, err := handler(ctx, req)
		code := status.Code(err).String()
		duration := time.Since(start).Seconds()
		m.requestsTotal.WithLabelValues(m.serviceName, info.FullMethod, code).Inc()
		m.requestDuration.WithLabelValues(m.serviceName, info.FullMethod, code).Observe(duration)
		return resp, err
	}
}
