// Command healthcheck calls the standard gRPC health service and exits
// with status 0 if SERVING, or status 1 otherwise.
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
)

func main() {
	addr := flag.String("addr", "localhost:50051", "gRPC server address")
	timeout := flag.Duration("timeout", 5*time.Second, "dial and RPC deadline")
	flag.Parse()

	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()

	conn, err := grpc.NewClient(*addr,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		fmt.Fprintf(os.Stderr, "healthcheck: failed to connect to %s: %v\n", *addr, err)
		os.Exit(1)
	}
	defer conn.Close()

	client := healthpb.NewHealthClient(conn)
	resp, err := client.Check(ctx, &healthpb.HealthCheckRequest{Service: ""})
	if err != nil {
		fmt.Fprintf(os.Stderr, "healthcheck: Check RPC failed: %v\n", err)
		os.Exit(1)
	}

	if resp.Status != healthpb.HealthCheckResponse_SERVING {
		fmt.Fprintf(os.Stderr, "healthcheck: server status is %s\n", resp.Status)
		os.Exit(1)
	}

	fmt.Printf("healthcheck OK: %s\n", resp.Status)
}
