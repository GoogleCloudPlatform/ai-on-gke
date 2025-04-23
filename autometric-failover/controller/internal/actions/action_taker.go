package actions

import (
	"context"
	"errors"
	"fmt"

	v1 "github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/api/v1"
	"github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/internal/utils"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/client-go/tools/record"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"
	jobsetv1a "sigs.k8s.io/jobset/api/jobset/v1alpha2"
)

const (
	EventReasonFailoverActionTriggered       = "FailoverActionTriggered"
	EventReasonDryRunFailoverActionTriggered = "DryRunFailoverActionTriggered"
)

// GCPClient defines the interface for managing GCP compute instances
type GCPClient interface {
	DeleteInstance(ctx context.Context, project, zone, instance string) error
}

type NoOpGCPClient struct{}

func (m *NoOpGCPClient) DeleteInstance(ctx context.Context, project, zone, instance string) error {
	log := log.FromContext(ctx)
	log.Info("No-op GCP instance deletion", "project", project, "zone", zone, "instance", instance)
	return nil
}

// ActionTakerInterface defines the interface for taking actions
type ActionTakerInterface interface {
	TakeAction(ctx context.Context, req v1.ActionRequest) error
}

// NoOpActionTaker implements ActionTakerInterface with no-op behavior
type NoOpActionTaker struct{}

func (n *NoOpActionTaker) TakeAction(ctx context.Context, req v1.ActionRequest) error {
	log := log.FromContext(ctx)
	log.Info("No-op action taken", "req", req)
	return nil
}

type ActionTaker struct {
	Client          client.Client
	InstanceManager GCPClient
	EventRecorder   record.EventRecorder
	RateLimiter     RateLimiter
}

func NewActionTaker(ctx context.Context, client client.Client, instanceManager GCPClient, rec record.EventRecorder, rateLimiter RateLimiter) *ActionTaker {
	return &ActionTaker{
		Client:          client,
		InstanceManager: instanceManager,
		EventRecorder:   rec,
		RateLimiter:     rateLimiter,
	}
}

// RestartJobSetLeader finds and deletes the leader pod for a JobSet to trigger a restart
func (a *ActionTaker) RestartJobSetLeader(ctx context.Context, req *actionRequest) error {
	// List pods with the JobSet leader labels
	var podList corev1.PodList
	labels := client.MatchingLabels{
		"jobset.sigs.k8s.io/jobset-name":           req.JobSetName,
		"batch.kubernetes.io/job-completion-index": "0",
	}

	if err := a.Client.List(ctx, &podList, client.InNamespace(req.Namespace), labels); err != nil {
		return fmt.Errorf("failed to list pods: %v", err)
	}

	if len(podList.Items) == 0 {
		return fmt.Errorf("no leader pod found for JobSet %s in namespace %s", req.JobSetName, req.Namespace)
	}

	// Delete the leader pod
	leaderPod := &podList.Items[0]
	if err := a.Client.Delete(ctx, leaderPod, &client.DeleteOptions{
		GracePeriodSeconds: &[]int64{0}[0], // Force delete
	}); err != nil {
		return fmt.Errorf("failed to delete leader pod %s: %v", leaderPod.Name, err)
	}

	return nil
}

func (a *ActionTaker) resolveNodeToPool(ctx context.Context, nodeName string) (string, error) {
	var node corev1.Node
	if err := a.Client.Get(ctx, types.NamespacedName{Name: nodeName}, &node); err != nil {
		return "", fmt.Errorf("failed to get node %s: %v", nodeName, err)
	}
	pool, ok := utils.GetNodePool(&node)
	if !ok {
		return "", fmt.Errorf("no node pool label found on node %s", nodeName)
	}
	return pool, nil
}

// RateLimitError is returned when an action is rate limited
var RateLimitError = errors.New("action is currently rate limited")

func (a *ActionTaker) TakeAction(ctx context.Context, req v1.ActionRequest) error {
	log := log.FromContext(ctx)

	if a.RateLimiter.IsRateLimited(req.Type) {
		return RateLimitError
	}

	resReq, err := resolveActionRequest(ctx, a.Client, req)
	if err != nil {
		return fmt.Errorf("failed to resolve action request: %v", err)
	}

	if err := a.fireEvent(resReq); err != nil {
		return fmt.Errorf("failed to fire event: %v", err)
	}

	if resReq.DryRun {
		log.Info("Dry run, skipping action", "action", req.Type, "jobsetName", req.JobSetName, "nodePool", req.NodePool)
		return nil
	}

	// Update rate limit before executing the action
	a.RateLimiter.UpdateRateLimit(req.Type)

	switch req.Type {
	case v1.ActionTypeCordonNodepool:
		return a.CordonNodePool(ctx, resReq)
	case v1.ActionTypeCordonNodepoolAndRestartJobSet:
		if err := a.CordonNodePool(ctx, resReq); err != nil {
			return fmt.Errorf("failed to cordon node pool: %v", err)
		}
		return a.RestartJobSetLeader(ctx, resReq)
	case v1.ActionTypeCordonAndRepairNodepool:
		if err := a.CordonNodePool(ctx, resReq); err != nil {
			return fmt.Errorf("failed to cordon node pool: %v", err)
		}
		return a.RepairNodePool(ctx, resReq)
	case v1.ActionTypeRepairNodepool:
		return a.RepairNodePool(ctx, resReq)
	default:
		return fmt.Errorf("unknown action type: %s", req.Type)
	}
}

func (a *ActionTaker) fireEvent(req *actionRequest) error {
	target, err := req.eventTarget()
	if err != nil {
		return fmt.Errorf("failed to get event target: %v", err)
	}

	var eventReason string
	if req.DryRun {
		eventReason = EventReasonDryRunFailoverActionTriggered
	} else {
		eventReason = EventReasonFailoverActionTriggered
	}
	a.EventRecorder.Eventf(target, corev1.EventTypeNormal, eventReason, "Failover action triggered: %s: %s", req.Type, req.Reason)

	return nil
}

// CordonNodePool cordons a node pool.
func (a *ActionTaker) CordonNodePool(ctx context.Context, req *actionRequest) error {
	for _, node := range req.resolvedNodeList {
		// Patch the Node to mark as unschedulable.
		// {"spec":{"unschedulable":true}}
		if err := a.Client.Patch(ctx, &node, client.RawPatch(types.StrategicMergePatchType, []byte(`{"spec":{"unschedulable":true}}`))); err != nil {
			return fmt.Errorf("failed to patch node %s: %v", node.Name, err)
		}
	}

	return nil
}

// RepairNodePool deletes a single GKE compute instance from the node pool to trigger a repair
func (a *ActionTaker) RepairNodePool(ctx context.Context, req *actionRequest) error {
	node := req.resolvedNode

	// Extract GCP instance details from provider ID.
	project, zone, instance, err := utils.ParseProviderID(node.Spec.ProviderID)
	if err != nil {
		return fmt.Errorf("parsing provider ID %s: %v", node.Spec.ProviderID, err)
	}

	// Delete the GCE instance
	if err := a.InstanceManager.DeleteInstance(ctx, project, zone, instance); err != nil {
		return fmt.Errorf("deleting instance: %v", err)
	}

	return nil
}

type actionRequest struct {
	v1.ActionRequest

	resolvedNodePool string
	resolvedNode     *corev1.Node
	resolvedNodeList []corev1.Node

	resolvedJobSet *jobsetv1a.JobSet
}

// resolveActionRequest resolves the action request into common info needed for actions.
func resolveActionRequest(ctx context.Context, c client.Client, req v1.ActionRequest) (*actionRequest, error) {
	r := &actionRequest{
		ActionRequest: req,
	}

	// Resolve JobSet Object
	if r.JobSetName != "" {
		r.resolvedJobSet = &jobsetv1a.JobSet{}
		if err := c.Get(ctx, types.NamespacedName{Namespace: r.Namespace, Name: r.JobSetName}, r.resolvedJobSet); err != nil {
			return nil, fmt.Errorf("failed to get JobSet %s in namespace %s: %v", r.JobSetName, r.Namespace, err)
		}
	}

	// Resolve Node Object
	if r.NodeName != "" {
		r.resolvedNode = &corev1.Node{}
		if err := c.Get(ctx, types.NamespacedName{Name: r.NodeName}, r.resolvedNode); err != nil {
			return nil, fmt.Errorf("failed to get node %s: %v", r.NodeName, err)
		}
	}

	// Resolve Node Pool Name
	if r.NodePool != "" {
		r.resolvedNodePool = r.NodePool
	} else if r.resolvedNode != nil {
		pool, ok := utils.GetNodePool(r.resolvedNode)
		if !ok {
			return nil, fmt.Errorf("no node pool label found on node %s", r.resolvedNode.Name)
		}
		r.resolvedNodePool = pool
	}

	// Resolve Node List
	if r.resolvedNodePool != "" {
		nodes, err := listNodesInPool(ctx, c, r.resolvedNodePool, false)
		if err != nil {
			return nil, fmt.Errorf("failed to list nodes in node pool %s: %v", r.resolvedNodePool, err)
		}
		r.resolvedNodeList = nodes
		if len(nodes) == 0 {
			return nil, fmt.Errorf("no nodes found in node pool %s", r.resolvedNodePool)
		}
		if r.resolvedNode == nil {
			r.resolvedNode = &nodes[0]
		}
	}

	return r, nil
}

func (r *actionRequest) eventTarget() (runtime.Object, error) {
	if r.resolvedJobSet != nil {
		return r.resolvedJobSet, nil
	}
	if r.resolvedNode != nil {
		return r.resolvedNode, nil
	}
	return nil, fmt.Errorf("no event target found")
}

func listNodesInPool(ctx context.Context, c client.Client, nodePool string, mustMatchExpectedCount bool) ([]corev1.Node, error) {
	var nodes corev1.NodeList
	if err := c.List(ctx, &nodes, &client.ListOptions{
		LabelSelector: labels.SelectorFromSet(map[string]string{
			utils.NodeLabelGKENodepool: nodePool,
		}),
	}); err != nil {
		return nil, err
	}

	if mustMatchExpectedCount && len(nodes.Items) == 0 {
		return nil, fmt.Errorf("no nodes found in node pool %s", nodePool)
	}
	if mustMatchExpectedCount {
		node0 := nodes.Items[0]
		expectedCount, err := utils.GetExpectedTPUNodePoolSize(&node0)
		if err != nil {
			return nil, fmt.Errorf("failed to get expected node pool size: by inspecting node %s: %v", node0.Name, err)
		}
		if len(nodes.Items) != int(expectedCount) {
			return nil, fmt.Errorf("expected %d nodes in node pool %s, found %d", expectedCount, nodePool, len(nodes.Items))
		}
	}
	return nodes.Items, nil
}

// NewNoRateLimiter creates a new NoRateLimiter
func NewNoRateLimiter() *NoRateLimiter {
	return &NoRateLimiter{}
}
