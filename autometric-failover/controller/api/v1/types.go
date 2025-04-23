package v1

import (
	"fmt"

	"github.com/google/uuid"
)

type ActionRequest struct {
	// ID is a unique identifier for the action request.
	// This will show up in logs and events.
	// Will be generated if it is not provided.
	ID string `json:"id"`

	// DryRun will just log and publish an event for the action, but not take any action.
	DryRun bool `json:"dry_run"`

	// Requestor is the user or system that requested the action.
	// Required.
	Requestor string `json:"requestor"`
	// Reason is a human-readable reason for the action.
	// Required.
	Reason string `json:"reason"`
	// Type is the type of action to perform.
	// Required.
	Type ActionType `json:"type"`

	// Namespace is the namespace of that the action pertains to.
	// Defaults to "default".
	Namespace string `json:"namespace"`

	// JobSetName is the name of the Kubernetes JobSet that the action pertains to.
	JobSetName string `json:"jobset_name"`

	// NodePool is the name of the node pool to be acted upon.
	NodePool string `json:"node_pool"`
	// NodeName is the name of the node to be acted upon.
	NodeName string `json:"node_name"`

	// PreflightChecks are a set of checks that will be performed to ensure that the action can be taken.
	PreflightChecks PreflightChecks `json:"preflight_checks"`
}

type PreflightChecks struct {
	// ExpectedNodeCounts will check that the expected number of nodes exist in the node pool
	// based on the TPU topology.
	ExpectedNodeCounts bool `json:"expected_node_counts"`
}

type ActionType string

const (
	// ActionTypeCordonNodepool marks all Nodes in a node pool as unschedulable.
	ActionTypeCordonNodepool ActionType = "cordon_nodepool"
	// ActionTypeCordonNodepoolAndRestartJobSet cordons a node pool and deletes the leader pod of a JobSet
	// to trigger a restart.
	ActionTypeCordonNodepoolAndRestartJobSet ActionType = "cordon_nodepool_and_restart_jobset"
	// ActionTypeCordonAndRepairNodepool cordons a node pool and deletes a single GKE compute instance
	// to trigger a repair.
	ActionTypeCordonAndRepairNodepool ActionType = "cordon_and_repair_nodepool"
	// ActionTypeRepairNodepool repairs a node pool by deleting a single GKE compute instance
	// to trigger a repair without cordoning.
	ActionTypeRepairNodepool ActionType = "repair_nodepool"
)

type ActionResponse struct {
	ID    string `json:"id"`
	Error string `json:"error,omitempty"`
}

// DefaultAndValidate performs validation of the ActionRequest fields
// after applying default values.
// All error messages will be expressed in terms of the JSON field names.
func (r *ActionRequest) DefaultAndValidate() error {
	if r.ID == "" {
		r.ID = uuid.New().String()
	}
	if r.Namespace == "" {
		r.Namespace = "default"
	}

	if r.Requestor == "" {
		return fmt.Errorf("requestor is required")
	}

	if r.Reason == "" {
		return fmt.Errorf("reason is required")
	}

	switch r.Type {
	case ActionTypeCordonNodepool, ActionTypeRepairNodepool, ActionTypeCordonAndRepairNodepool:
		if r.NodePool == "" && r.NodeName == "" {
			return fmt.Errorf("node_pool or node_name is required for %s action", r.Type)
		}
		return nil
	case ActionTypeCordonNodepoolAndRestartJobSet:
		if r.JobSetName == "" {
			return fmt.Errorf("jobset_name is required for %s action", r.Type)
		}
		return nil
	default:
		return fmt.Errorf("unknown action type: %s", r.Type)
	}
}
