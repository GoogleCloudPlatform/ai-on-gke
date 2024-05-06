package controller

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/GoogleCloudPlatform/ai-on-gke/tpu-provisioner/internal/cloud"

	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/client-go/tools/record"

	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller"
	ctrllog "sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/predicate"

	jobset "sigs.k8s.io/jobset/api/jobset/v1alpha2"
)

// DeletionReconciler watches Pods and Nodes and deletes Node Pools.
type DeletionReconciler struct {
	client.Client
	Scheme   *runtime.Scheme
	Recorder record.EventRecorder
	Provider cloud.Provider

	NodeCriteria NodeCriteria
	Concurrency  int
}

type NodeCriteria struct {
	MinLifetime time.Duration

	// PoolDeletionDelay is the interval between the first and
	// second node pool deletion checks. Once the node pool deletion check
	// has passed twice, the node pool can be safely deleted. This second
	// check is ensure the node pool is not prematurely deleted, in the case
	// where a JobSet is restarted, but no pods have been created yet.
	PoolDeletionDelay time.Duration
}

//+kubebuilder:rbac:groups="",resources=nodes,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups="",resources=nodes/status,verbs=get;update;patch
//+kubebuilder:rbac:groups="",resources=nodes/finalizers,verbs=update
//+kubebuilder:rbac:groups="jobset.x-k8s.io",resources=jobsets,verbs=get;list;watch

func (r *DeletionReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	lg := ctrllog.FromContext(ctx)

	lg.V(3).Info("Reconciling Node")

	var node corev1.Node
	if err := r.Get(ctx, req.NamespacedName, &node); err != nil {
		if apierrors.IsNotFound(err) {
			// Don't requeue, Node no longer exists (or does not exist in the cache).
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, fmt.Errorf("getting node: %w", err)
	}

	// NOTE: Because of the cache filter in main.go, this check should always evaluate to false.
	if node.GetLabels()[cloud.LabelNodepoolManager] != cloud.LabelNodepoolManagerTPUPodinator {
		lg.V(3).Info("Node was not provisioned by this controller, ignoring")
		return ctrl.Result{}, nil
	}

	// Avoid noisy reconciliation when nodes are shutting down.
	for _, c := range node.Status.Conditions {
		if c.Type == corev1.NodeReady &&
			c.Status == corev1.ConditionFalse &&
			c.Reason == "KubeletNotReady" &&
			c.Message == "node is shutting down" {
			lg.V(3).Info("Node is shutting down, ignoring")
			return ctrl.Result{}, nil
		}
	}

	// Ensure node was not just created to make sure Pods have had time to schedule.
	if since := time.Since(node.GetCreationTimestamp().Time); since < r.NodeCriteria.MinLifetime {
		wait := r.NodeCriteria.MinLifetime - since + time.Second
		lg.V(3).Info("Node was just created, ignoring", "waiting", wait)
		return ctrl.Result{RequeueAfter: wait}, nil
	}

	nodePoolLabelKey := r.Provider.NodePoolLabelKey()
	nodePoolName, ok := node.GetLabels()[nodePoolLabelKey]
	if !ok {
		lg.V(3).Info("No node pool label found on node, ignoring", "labelKey", nodePoolLabelKey)
		return ctrl.Result{}, nil
	}

	// Ensure the JobSet whose pods created this node pool is either gone, completed, or failed before
	// deleting the node pool.
	jobSetName, exists := node.Labels[cloud.LabelJobSetName]
	if !exists {
		lg.V(3).Info("Node missing jobset name label", "node", node.Name)
		return ctrl.Result{}, nil

	}
	jobSetNamespace, exists := node.Labels[cloud.LabelJobSetNamespace]
	if !exists {
		lg.V(3).Info("Node missing jobset namespace label", "node", node.Name)
		return ctrl.Result{}, nil
	}
	var js jobset.JobSet
	if err := r.Get(ctx, types.NamespacedName{Name: jobSetName, Namespace: jobSetNamespace}, &js); err != nil {
		// Case 1: If JobSet no longer exists, delete the node pool.
		if apierrors.IsNotFound(err) {
			return r.deleteNodePool(ctx, &node, fmt.Sprintf("JobSet %s no longer exists", jobSetName))
		}
		return ctrl.Result{}, err
	}
	// Case 2: if JobSet is in completed or failed state, delete node pool.
	if jobSetCompleted(&js) || jobSetFailed(&js) {
		return r.deleteNodePool(ctx, &node, fmt.Sprintf("JobSet %s execution has ended (completed or failed)", jobSetName))
	}

	// No need to check all the other nodes, which will have the same jobset name label, we can end
	// the loop early.
	// Log the fact we are not deleting at a high verbosity level to avoid polluting logs but
	// allow for improved debugability.
	lg.V(5).Info("Node pool %s for JobSet %s is still in use, not deleting", nodePoolName, jobSetName)
	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *DeletionReconciler) SetupWithManager(mgr ctrl.Manager) error {
	if err := mgr.GetFieldIndexer().IndexField(context.Background(), &corev1.Pod{}, ".spec.nodeName", func(rawObj client.Object) []string {
		pod := rawObj.(*corev1.Pod)
		return []string{pod.Spec.NodeName}
	}); err != nil {
		return err
	}

	if r.NodeCriteria.MinLifetime == 0 {
		return fmt.Errorf("NodeCriteria.MinLifetime must be set")
	}

	return ctrl.NewControllerManagedBy(mgr).
		For(&corev1.Node{}).
		WithOptions(controller.Options{
			MaxConcurrentReconciles: r.Concurrency,
		}).
		WithEventFilter(predicate.NewPredicateFuncs(func(object client.Object) bool {
			node, ok := object.(*corev1.Node)
			return ok && nodeManagedByProvisioner(node)
		})).
		Complete(r)
}

func (r *DeletionReconciler) deleteNodePool(ctx context.Context, node *corev1.Node, reason string) (ctrl.Result, error) {
	lg := ctrllog.FromContext(ctx)
	if err := r.Provider.DeleteNodePoolForNode(node, reason); err != nil {
		if errors.Is(err, cloud.ErrDuplicateRequest) {
			lg.V(3).Info("Ignoring duplicate request to delete node pool")
			return ctrl.Result{}, nil
		}
	}
	return ctrl.Result{}, nil
}

// nodeManagedByProvisioner returns true if the given node is managed by the
// TPU provisioner, otherwise it returns false.
func nodeManagedByProvisioner(node *corev1.Node) bool {
	return node.Labels[cloud.LabelNodepoolManager] == cloud.LabelNodepoolManagerTPUPodinator
}

// jobSetCompleted returns true if the JobSet has completed, otherwise it returns false.
func jobSetCompleted(js *jobset.JobSet) bool {
	for _, condition := range js.Status.Conditions {
		if condition.Type == string(jobset.JobSetCompleted) && condition.Status == metav1.ConditionTrue {
			return true
		}
	}
	return false
}

// jobSetFailed returns true if the JobSet has failed, otherwise it returns false.
func jobSetFailed(js *jobset.JobSet) bool {
	for _, condition := range js.Status.Conditions {
		if condition.Type == string(jobset.JobSetFailed) && condition.Status == metav1.ConditionTrue {
			return true
		}
	}
	return false
}
