package utils

import (
	"fmt"
	"strconv"
	"strings"

	corev1 "k8s.io/api/core/v1"
)

func GetExpectedTPUNodePoolSize(node *corev1.Node) (int32, error) {
	if node.Labels == nil {
		return 0, fmt.Errorf("no annotations")
	}
	const topoKey = NodeLabelGKETPUTopology
	topoVal, ok := node.Labels[topoKey]
	if !ok {
		return 0, fmt.Errorf("no topology annotation: %q", topoKey)
	}
	const acceleratorCountKey = NodeLabelGKEAcceleratorCount
	acceleratorCountVal, ok := node.Labels[acceleratorCountKey]
	if !ok {
		return 0, fmt.Errorf("no accelerator annotation: %q", acceleratorCountKey)
	}
	acceleratorCount, err := strconv.Atoi(acceleratorCountVal)
	if err != nil {
		return 0, fmt.Errorf("failed to parse accelerator count: %w", err)
	}
	if acceleratorCount < 1 {
		return 0, fmt.Errorf("invalid accelerator count: %d", acceleratorCount)
	}

	product, err := TPUTopologyToChipCount(topoVal)
	if err != nil {
		return 0, err
	}
	return int32(product / acceleratorCount), nil
}

func TPUTopologyToChipCount(topo string) (int, error) {
	// TODO: Do we need to validate expectedDims? GKE won't run the jobset if this is invalid?
	split := strings.Split(topo, "x")
	if len(split) < 2 {
		return 0, fmt.Errorf("invalid topology: %q", topo)
	}
	product := 1
	for _, s := range split {
		x, err := strconv.Atoi(s)
		if err != nil {
			return 0, fmt.Errorf("invalid topology: %v, could not convert %q to int: %w", topo, s, err)
		}
		product *= x
	}
	return product, nil
}

// ParseProviderID extracts GCP project, zone, and instance name from a k8s Node's providerID
// Example providerID format: gce://my-project-id/us-east5-a/my-instance-name
func ParseProviderID(providerID string) (project, zone, instance string, err error) {
	if !strings.HasPrefix(providerID, "gce://") {
		return "", "", "", fmt.Errorf("invalid GCE provider ID format: %s", providerID)
	}

	parts := strings.Split(strings.TrimPrefix(providerID, "gce://"), "/")
	if len(parts) != 3 {
		return "", "", "", fmt.Errorf("invalid GCE provider ID format: %s", providerID)
	}

	return parts[0], parts[1], parts[2], nil
}

func GetNodePool(node *corev1.Node) (string, bool) {
	if node.Labels == nil {
		return "", false
	}
	val, ok := node.Labels[NodeLabelGKENodepool]
	return val, ok
}
