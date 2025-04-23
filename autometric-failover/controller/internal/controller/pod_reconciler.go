package controller

import (
	"context"
	"fmt"

	"github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/internal/historydb"
	"github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/internal/utils"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

const (
	PodLabelJobName    = "batch.kubernetes.io/job-name"
	PodLabelJobSetName = "jobset.sigs.k8s.io/jobset-name"
)

// PodReconciler watches for JobSet Job leader Pods and labels the Job once Node scheduling
// has occurred to keep track of dynamic Job-to-NodePool relationships.
type PodReconciler struct {
	client.Client
	HistoryDB                   historydb.DBInterface
	Scheme                      *runtime.Scheme
	DisableNodePoolJobLabelling bool
}

func (r *PodReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	//log := log.FromContext(ctx)
	//log.Info("reconciling", "req", req.NamespacedName)

	var pod corev1.Pod
	if err := r.Get(ctx, req.NamespacedName, &pod); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	if pod.Labels == nil {
		return ctrl.Result{}, nil
	}

	rec, err := r.buildJobStatusRecord(ctx, pod)
	if err != nil {
		return ctrl.Result{}, fmt.Errorf("failed to build job status record for pod %s: %w", pod.Name, err)
	}

	if err := r.HistoryDB.SaveJobStatus(rec); err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *PodReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&corev1.Pod{}).
		Complete(r)
}

// buildJobStatusRecord builds a JobStatusRecord from a Pod.
//
// Example Pod:
//
// apiVersion: v1
// kind: Pod
// metadata:
//
//	annotations:
//	  batch.kubernetes.io/job-completion-index: "0"
//	  jobset.sigs.k8s.io/global-replicas: "3"
//	  jobset.sigs.k8s.io/job-global-index: "0"
//	  jobset.sigs.k8s.io/job-index: "0"
//	  jobset.sigs.k8s.io/job-key: 60409ea10790a63a8d0b1deb4a9c001b0c91ef95
//	  jobset.sigs.k8s.io/jobset-name: example-jobset
//	  jobset.sigs.k8s.io/replicatedjob-name: rs-a
//	  jobset.sigs.k8s.io/replicatedjob-replicas: "1"
//	  jobset.sigs.k8s.io/restart-attempt: "0"
//	creationTimestamp: "2025-04-02T19:05:04Z"
//	finalizers:
//	- batch.kubernetes.io/job-tracking
//	generateName: example-jobset-rs-a-0-0-
//	labels:
//	  batch.kubernetes.io/controller-uid: ee766c9c-0109-4705-aa17-f397c534e963
//	  batch.kubernetes.io/job-completion-index: "0"
//	  batch.kubernetes.io/job-name: example-jobset-rs-a-0
//	  controller-uid: ee766c9c-0109-4705-aa17-f397c534e963
//	  job-name: example-jobset-rs-a-0
//	  jobset.sigs.k8s.io/global-replicas: "3"
//	  jobset.sigs.k8s.io/job-global-index: "0"
//	  jobset.sigs.k8s.io/job-index: "0"
//	  jobset.sigs.k8s.io/job-key: 60409ea10790a63a8d0b1deb4a9c001b0c91ef95
//	  jobset.sigs.k8s.io/jobset-name: example-jobset
//	  jobset.sigs.k8s.io/replicatedjob-name: rs-a
//	  jobset.sigs.k8s.io/replicatedjob-replicas: "1"
//	  jobset.sigs.k8s.io/restart-attempt: "0"
//	name: example-jobset-rs-a-0-0-x2277
//	namespace: default
//	ownerReferences:
//	- apiVersion: batch/v1
//	  blockOwnerDeletion: true
//	  controller: true
//	  kind: Job
//	  name: example-jobset-rs-a-0
//	  uid: ee766c9c-0109-4705-aa17-f397c534e963
//	resourceVersion: "840"
//	uid: 2e9d0d20-18a2-4877-b03a-ddf0266e4528
func (r *PodReconciler) buildJobStatusRecord(ctx context.Context, pod corev1.Pod) (*historydb.JobStatusRecord, error) {
	var rec historydb.JobStatusRecord
	jobName, ok := pod.Labels[PodLabelJobName]
	if !ok {
		return nil, fmt.Errorf("failed to get job name for pods")
	}
	rec.JobName = jobName

	jobSetName, ok := pod.Labels[PodLabelJobSetName]
	if !ok {
		return nil, fmt.Errorf("failed to get job set name for pods")
	}
	rec.JobSetName = jobSetName

	for _, owner := range pod.OwnerReferences {
		if owner.Kind == "Job" {
			rec.JobUID = string(owner.UID)
			break
		}
	}
	if rec.JobUID == "" {
		return nil, fmt.Errorf("failed to get job uid for pods")
	}

	if pod.Spec.NodeName == "" {
		if isUnschedulable(&pod) {
			rec.Status = historydb.JobStatusUnschedulable
		} else {
			rec.Status = historydb.JobStatusPending
		}
	} else {
		rec.Status = historydb.JobStatusScheduled
		var node corev1.Node
		if err := r.Get(ctx, client.ObjectKey{Name: pod.Spec.NodeName}, &node); err != nil {
			return nil, fmt.Errorf("failed to get node for pods: %w", err)
		}
		nodePool, ok := utils.GetNodePool(&node)
		if !ok {
			return nil, fmt.Errorf("failed to get node pool for pod from node label")
		}
		rec.NodePool = nodePool
	}

	return &rec, nil
}

func isUnschedulable(p *corev1.Pod) bool {
	for _, c := range p.Status.Conditions {
		if c.Type == corev1.PodScheduled &&
			c.Status == corev1.ConditionFalse &&
			c.Reason == corev1.PodReasonUnschedulable {
			return true
		}
	}
	return false
}
