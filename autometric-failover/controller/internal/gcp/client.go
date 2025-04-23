package gcp

import (
	"context"
	"fmt"

	compute "google.golang.org/api/compute/v1"
)

// Client handles GCP operations.
type Client struct {
	computeService *compute.Service
}

// NewClient creates a new Client.
func NewClient(ctx context.Context) (*Client, error) {
	computeService, err := compute.NewService(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to create compute service: %v", err)
	}

	return &Client{
		computeService: computeService,
	}, nil
}

// DeleteInstance deletes a GCE instance
func (m *Client) DeleteInstance(ctx context.Context, project, zone, instance string) error {
	_, err := m.computeService.Instances.Delete(project, zone, instance).Context(ctx).Do()
	if err != nil {
		return fmt.Errorf("failed to delete instance %s: %v", instance, err)
	}

	// Deletion request accepted.
	// Return early instead of waiting for the operation to complete.
	// The instance will be deleted asynchronously.

	return nil
}
