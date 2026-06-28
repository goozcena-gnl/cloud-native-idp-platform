package telemetry

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

// TracingShutdown flushes and stops the OpenTelemetry tracer provider.
type TracingShutdown func(context.Context) error

// InitTracing configures OpenTelemetry tracing when enabled.
// It exports spans to an OTLP gRPC endpoint such as Tempo on port 4317.
func InitTracing(
	ctx context.Context,
	logger *slog.Logger,
	serviceName string,
	version string,
	endpoint string,
	enabled bool,
) (TracingShutdown, error) {
	if !enabled {
		logger.Info("OpenTelemetry tracing disabled")
		return func(context.Context) error { return nil }, nil
	}

	if endpoint == "" {
		return nil, fmt.Errorf("OpenTelemetry tracing enabled but OTEL_EXPORTER_OTLP_ENDPOINT is empty")
	}

	exporterCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	exporter, err := otlptracegrpc.New(
		exporterCtx,
		otlptracegrpc.WithEndpoint(endpoint),
		otlptracegrpc.WithInsecure(),
	)
	if err != nil {
		return nil, fmt.Errorf("create OTLP trace exporter: %w", err)
	}

	res, err := resource.New(
		ctx,
		resource.WithAttributes(
			attribute.String("service.name", serviceName),
			attribute.String("service.version", version),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("create OpenTelemetry resource: %w", err)
	}

	tracerProvider := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
	)

	otel.SetTracerProvider(tracerProvider)
	otel.SetTextMapPropagator(
		propagation.NewCompositeTextMapPropagator(
			propagation.TraceContext{},
			propagation.Baggage{},
		),
	)

	logger.Info("OpenTelemetry tracing enabled",
		"service", serviceName,
		"version", version,
		"otlp_endpoint", endpoint,
	)

	return tracerProvider.Shutdown, nil
}
