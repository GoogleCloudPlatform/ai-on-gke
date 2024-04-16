package cloud

import (
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	containerv1beta1 "google.golang.org/api/container/v1beta1"
	"google.golang.org/api/googleapi"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/client-go/tools/record"
	"sigs.k8s.io/controller-runtime/pkg/client"
	logf "sigs.k8s.io/controller-runtime/pkg/log"
)

var log = logf.Log.WithName("provider")

const (
	GKETPUNodeSelector         = "cloud.google.com/gke-tpu-topology"
	GKEAcceleratorNodeSelector = "cloud.google.com/gke-tpu-accelerator"
	GKENodePoolNameLabel       = "cloud.google.com/gke-nodepool"
	GKENodePoolNamePrefix      = "tpu-provisioner-"
	jobKeyLabel                = "jobset.sigs.k8s.io/job-key"
	V4PodSliceAccelerator      = "tpu-v4-podslice"
	V5ePodSliceAccelerator     = "tpu-v5-lite-podslice"
	V5pPodSliceAccelerator     = "tpu-v5p-slice"
	GoogleTPUResource          = "google.com/tpu"
	gcpLabelPrefix             = "cloud.google.com/"
	googleLabelPrefix          = "google.com/"
	// Default max pods per node is 110, but a lower value is necessary for large scale clusters,
	// otherwise we'll run out of IP Space and provisioning will fail.
	// 15 pods per node will work for small and large cluster sizes, given the TPU constraint of
	// 1 pod per TPU node + kube-system pods
	// TODO: move this to a environment variable
	maxPodsPerNode = 15
)

var _ Provider = &GKE{}

type GKE struct {
	Service        *containerv1beta1.Service
	ClusterContext GKEContext

	Recorder record.EventRecorder

	inProgressDeletesNPName sync.Map
	inProgressCreatesNPName sync.Map
	inProgressCreatesJobKey sync.Map
}

func (g *GKE) NodePoolLabelKey() string { return GKENodePoolNameLabel }

func (g *GKE) EnsureNodePoolForPod(p *corev1.Pod, why string) error {
	name := podToNodePoolName(p, GKENodePoolNamePrefix, "")

	exists, err := g.nodePoolExists(name)
	if err != nil {
		return fmt.Errorf("checking if node pool exists: %w", err)
	}
	if exists {
		return nil
	}

	np, err := g.nodePoolForPod(name, p)
	if err != nil {
		return fmt.Errorf("determining node pool for pod: %w", err)
	}

	req := &containerv1beta1.CreateNodePoolRequest{
		NodePool: np,
		Parent:   g.ClusterContext.ClusterName(),
	}

	// Due to concurrent reconciles, multiple creates for the same
	// Node Pool will occur at the same time. The result is an error:
	// "do: googleapi: Error 400: Cluster is running incompatible operation ..."
	// To avoid a bunch of failed requests, we dedeuplicate here.
	if _, inProgress := g.inProgressCreatesNPName.Load(name); inProgress {
		return fmt.Errorf("creation ongoing for node pool name: %v: %w", name, ErrDuplicateRequest)
	}
	g.inProgressCreatesNPName.Store(name, struct{}{})
	defer g.inProgressCreatesNPName.Delete(name)

	// A restarting JobSet will trigger a new Node Pool creation.
	// The current creation attempt might overlap with the previous one,
	// which could still be ongoing, so we need to deduplicate.
	// This works because job-key remains constant across restarts.
	// NOTE: These checks dont work across controller restarts.
	if jobKey := p.Labels[jobKeyLabel]; jobKey != "" {
		if _, inProgress := g.inProgressCreatesJobKey.Load(jobKey); inProgress {
			return fmt.Errorf("creation ongoing for job-key: %v: %w", jobKey, ErrDuplicateRequest)
		}
		g.inProgressCreatesJobKey.Store(jobKey, struct{}{})
		defer g.inProgressCreatesJobKey.Delete(jobKey)
	}

	g.Recorder.Eventf(p, corev1.EventTypeNormal, EventNodePoolCreationStarted, "Starting creation of Node Pool %s (size = %v) because %s", name, np.InitialNodeCount, why)
	call := g.Service.Projects.Locations.Clusters.NodePools.Create(g.ClusterContext.ClusterName(), req)
	op, err := call.Do()
	if err != nil {
		g.Recorder.Eventf(p, corev1.EventTypeWarning, EventNodePoolCreationFailed, "Request to create Node Pool %s failed: %v.", name, err)
		return fmt.Errorf("do: %w", err)
	}

	if err := waitForGkeOp(g.Service, g.ClusterContext, op); err != nil {
		g.Recorder.Eventf(p, corev1.EventTypeWarning, EventNodePoolCreationFailed, "Operation to create Node Pool %s failed: %v.", name, err)
		return fmt.Errorf("waiting for operation: %w", err)
	}

	g.Recorder.Eventf(p, corev1.EventTypeNormal, EventNodePoolCreationSucceeded, "Successfully created Node Pool %s.", name)

	return nil
}

func (g *GKE) ListNodePools() ([]NodePoolRef, error) {
	var refs []NodePoolRef

	resp, err := g.Service.Projects.Locations.Clusters.NodePools.List(g.ClusterContext.ClusterName()).Do()
	if err != nil {
		return nil, fmt.Errorf("listing node pools: %w", err)

	}

	for _, np := range resp.NodePools {
		refs = append(refs, NodePoolRef{
			Name:    np.Name,
			Error:   np.Status == "ERROR",
			Message: np.StatusMessage,
			CreatedForPod: types.NamespacedName{
				Name:      np.Config.Labels[LabelPodName],
				Namespace: np.Config.Labels[LabelPodNamespace],
			},
		})
	}

	return refs, nil
}

func (g *GKE) DeleteNodePoolForNode(node *corev1.Node, why string) error {
	name, ok := node.GetLabels()[g.NodePoolLabelKey()]
	if !ok {
		return fmt.Errorf("node %q does not have node pool label", node.Name)
	}

	return g.DeleteNodePool(name, node, why)
}

func (g *GKE) DeleteNodePool(name string, eventObj client.Object, why string) error {
	// Due to concurrent reconciles, multiple deletes for the same
	// Node Pool will occur at the same time. The result is an error:
	// To avoid a bunch of failed requests, we dedeuplicate here.
	if _, inProgress := g.inProgressDeletesNPName.Load(name); inProgress {
		return ErrDuplicateRequest
	}
	g.inProgressDeletesNPName.Store(name, struct{}{})
	defer g.inProgressDeletesNPName.Delete(name)

	g.Recorder.Eventf(eventObj, corev1.EventTypeNormal, EventNodePoolDeletionStarted, "Starting deletion of Node Pool %s because %s", name, why)
	op, err := g.Service.Projects.Locations.Clusters.Delete(g.ClusterContext.NodePoolName(name)).Do()
	if err != nil {
		if gerr, ok := err.(*googleapi.Error); ok && gerr.Code == http.StatusNotFound {
			g.Recorder.Eventf(eventObj, corev1.EventTypeNormal, EventNodePoolNotFound, "Node pool not found - ignoring deletion attempt.", name)
			return nil
		}
		g.Recorder.Eventf(eventObj, corev1.EventTypeWarning, EventNodePoolDeletionFailed, "Request to delete Node Pool %s failed: %v.", name, err)
		return fmt.Errorf("deleting node pool %q: %w", name, err)
	}

	if err := waitForGkeOp(g.Service, g.ClusterContext, op); err != nil {
		g.Recorder.Eventf(eventObj, corev1.EventTypeWarning, EventNodePoolDeletionFailed, "Operation to delete Node Pool %s failed: %v.", name, err)
		return err
	}

	g.Recorder.Eventf(eventObj, corev1.EventTypeNormal, EventNodePoolDeletionSucceeded, "Successfully deleted Node Pool %s.", name)

	return nil
}

var ErrNodePoolStopping = errors.New("node pool stopping")

func (g *GKE) nodePoolExists(name string) (bool, error) {
	call := g.Service.Projects.Locations.Clusters.NodePools.Get(g.ClusterContext.NodePoolName(name))
	np, err := call.Do()
	if err == nil {
		return true, nil
	}
	if gerr, ok := err.(*googleapi.Error); ok && gerr.Code == http.StatusNotFound {
		return false, nil
	}
	if np.Status == "STOPPING" {
		return false, ErrNodePoolStopping
	}

	return false, err
}

func (g *GKE) nodePoolForPod(name string, p *corev1.Pod) (*containerv1beta1.NodePool, error) {
	ref := metav1.GetControllerOf(p)
	if ref == nil {
		// TODO: Allow for standalone Pods?
		return nil, errors.New("no owner reference")
	}

	labels := map[string]string{
		// Used to keep track of what Node Pools this provisioner is responsible for.
		LabelNodepoolManager: LabelNodepoolManagerTPUPodinator,

		// Leave some bread crumbs:
		LabelParentKind: strings.ToLower(ref.Kind),
		LabelParentName: strings.ToLower(ref.Name),
		// Assuming a Namespaced parent here...
		LabelParentNamespace: strings.ToLower(p.Namespace),

		LabelPodName:      p.Name,
		LabelPodNamespace: p.Namespace,
	}

	for k, v := range p.Spec.NodeSelector {
		// Don't copy GCP/Google labels onto the node.
		if !strings.HasPrefix(k, gcpLabelPrefix) && !strings.HasPrefix(k, googleLabelPrefix) {
			labels[k] = v
		}
	}

	// Pod should already be filtered for this Node Selector at this point.
	tpuTopo, ok := p.Spec.NodeSelector[GKETPUNodeSelector]
	if !ok {
		return nil, fmt.Errorf("missing node selector key: %v", GKETPUNodeSelector)
	}
	accel, ok := p.Spec.NodeSelector[GKEAcceleratorNodeSelector]
	if !ok {
		return nil, fmt.Errorf("missing node selector key: %v", GKEAcceleratorNodeSelector)
	}
	tpuRequest, err := sumTPURequests(p)
	if err != nil {
		return nil, fmt.Errorf("summing TPU requests: %w", err)
	}

	nodeCount, err := tpuTopologyToNodeCount(accel, tpuTopo)
	if err != nil {
		return nil, fmt.Errorf("determining node count: %w", err)
	}
	machineType, err := tpuMachineType(accel, tpuRequest)
	if err != nil {
		return nil, fmt.Errorf("determining node count: %w", err)
	}

	var reservation *containerv1beta1.ReservationAffinity
	if resName, ok := p.Spec.NodeSelector["cloud.google.com/reservation-name"]; ok {
		reservation = &containerv1beta1.ReservationAffinity{
			ConsumeReservationType: "SPECIFIC_RESERVATION",
			Key:                    "compute.googleapis.com/reservation-name",
			Values: []string{
				resName,
			},
		}
	}

	var taints []*containerv1beta1.NodeTaint

	spot := p.Spec.NodeSelector["cloud.google.com/gke-spot"] == "true"
	if spot {
		// Add the taint that NAP would add.
		// https://cloud.google.com/kubernetes-engine/docs/concepts/spot-vms#spotvms-nap
		taints = append(taints, &containerv1beta1.NodeTaint{
			Key:    "cloud.google.com/gke-spot",
			Value:  "true",
			Effect: "NO_SCHEDULE",
		})
	}

	var secondaryDisks []containerv1beta1.SecondaryBootDisk
	if g.ClusterContext.NodeSecondaryDisk != "" {
		secondaryDisks = []containerv1beta1.SecondaryBootDisk{
			{
				// Example: "projects/my-gcp-project/global/images/my-disk-image"
				DiskImage: g.ClusterContext.NodeSecondaryDisk,
				Mode:      "CONTAINER_IMAGE_CACHE",
			},
		}
	}

	return &containerv1beta1.NodePool{
		Name: name,
		Config: &containerv1beta1.NodeConfig{
			ServiceAccount: g.ClusterContext.NodeServiceAccount,
			ShieldedInstanceConfig: &containerv1beta1.ShieldedInstanceConfig{
				EnableIntegrityMonitoring: true,
				EnableSecureBoot:          g.ClusterContext.NodeSecureBoot,
			},
			Tags: g.ClusterContext.NodeTags,
			// NOTE: vendor/ was manually updated to include the field because
			// it was not currently available at the time of writing:
			SecondaryBootDisks:  secondaryDisks,
			MachineType:         machineType,
			ReservationAffinity: reservation,
			Labels:              labels,
			Spot:                spot,
			Taints:              taints,
		},
		InitialNodeCount: int64(nodeCount),
		Locations:        []string{g.ClusterContext.NodeZone},
		PlacementPolicy: &containerv1beta1.PlacementPolicy{
			TpuTopology: tpuTopo,
			Type:        "COMPACT",
		},
		Management: &containerv1beta1.NodeManagement{
			AutoRepair:  true,
			AutoUpgrade: true,
		},
		UpgradeSettings: &containerv1beta1.UpgradeSettings{
			MaxSurge: 1,
		},
		MaxPodsConstraint: &containerv1beta1.MaxPodsConstraint{MaxPodsPerNode: maxPodsPerNode},
	}, nil
}

func sumTPURequests(p *corev1.Pod) (int, error) {
	var n int
	for _, c := range p.Spec.Containers {
		if c.Resources.Requests == nil {
			continue
		}
		req, ok := c.Resources.Requests[corev1.ResourceName(GoogleTPUResource)]
		if !ok {
			continue
		}
		v, ok := req.AsInt64()
		if !ok {
			return 0, fmt.Errorf(("invalid TPU request: %v"), req.String())
		}
		n += int(v)
	}
	return n, nil
}

func podToNodePoolName(p *corev1.Pod, prefix, suffix string) string {
	// Use the UID of the Pod's owner (falling back to the Pod UID if it has
	// no owner) as the unique identifier for the node pool.
	// It is necessary to use something that is unique to the Pod not the Job/JobSet
	// because the scheduler is not guaranteed to place Pods on the same
	// node pools that were created for them. This commonly happens when
	// node pools are reused by other Jobs after the original Job has completed
	// or restarted. Using another identifier like the job-key could result in
	// deadlocks in this case.
	var uid string
	ref := metav1.GetControllerOf(p)
	if ref != nil {
		uid = string(ref.UID)
	} else {
		uid = string(p.UID)
	}
	return prefix + uid[0:12] + suffix
}

func tpuTopologyToNodeCount(accelerator, topo string) (int, error) {
	var expectedDims int
	switch accelerator {
	case V4PodSliceAccelerator, V5pPodSliceAccelerator:
		expectedDims = 3
	case V5ePodSliceAccelerator:
		expectedDims = 2
	default:
		return 0, fmt.Errorf("invalid accelerator: %v", accelerator)
	}

	split := strings.Split(topo, "x")
	if len(split) != expectedDims {
		return 0, fmt.Errorf("invalid topology: %v, expected %v dimensions", topo, expectedDims)
	}

	product := 1
	for _, s := range split {
		x, err := strconv.Atoi(s)
		if err != nil {
			return 0, fmt.Errorf("invalid topology: %v, could not convert %q to int: %w", topo, s, err)
		}
		product *= x
	}

	return product / 4, nil
}

// tpuMachineType takes an accelerator type (from nodeSelector) and a TPU request
// from container requests and returns the corresponding machine type.
func tpuMachineType(accel string, tpuRequest int) (string, error) {
	if tpuRequest < 1 {
		return "", fmt.Errorf("invalid TPU request: %v", tpuRequest)
	}

	switch accel {
	case V4PodSliceAccelerator: // v4
		return fmt.Sprintf("ct4p-hightpu-%vt", tpuRequest), nil
	case V5ePodSliceAccelerator: // v5e
		return fmt.Sprintf("ct5lp-hightpu-%vt", tpuRequest), nil
	case V5pPodSliceAccelerator: // v5p
		return fmt.Sprintf("ct5p-hightpu-%vt", tpuRequest), nil
	}

	return "", fmt.Errorf("invalid accelerator: %v", accel)
}

func waitForGkeOp(svc *containerv1beta1.Service, c GKEContext, operation *containerv1beta1.Operation) error {
	operationWaitTimeout := 30 * time.Minute
	operationPollInterval := 5 * time.Second

	for start := time.Now(); time.Since(start) < operationWaitTimeout; time.Sleep(operationPollInterval) {
		if op, err := svc.Projects.Locations.Operations.Get(c.OpName(operation.Name)).Do(); err == nil {
			if op.Status == "DONE" {
				return nil
			}
		} else {
			return fmt.Errorf("waiting for operation: %w", err)
		}
	}

	return fmt.Errorf("timeout while waiting for operation %s on %s to complete", operation.Name, operation.TargetLink)
}
