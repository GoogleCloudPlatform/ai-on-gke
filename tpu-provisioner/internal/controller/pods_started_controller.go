/*
Copyright 2023.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controller

import (
	"context"
	"fmt"
	"strconv"

	"github.com/GoogleCloudPlatform/ai-on-gke/tpu-provisioner/internal/cloud"

	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/client-go/tools/record"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	ctrllog "sigs.k8s.io/controller-runtime/pkg/log"
)

// PodsStartedReconciler watches Pods and updates a ConfigMap when a minimum number of
// associated Pods have started.
// It assumes that these Pods are managed by a JobSet, otherwise it will ignore them.
// The threshold is set via an annotation and is intended to be the total number of Pods
// in the JobSet - allowing for semi-synchronous startup across an entire JobSet.
// This threshold annotation is used to avoid a lookup of the number of replicas in the JobSet.
type PodsStartedReconciler struct {
	client.Client
	Scheme   *runtime.Scheme
	Recorder record.EventRecorder

	Provider cloud.Provider
}

//+kubebuilder:rbac:groups="",resources=configmaps,verbs=get;list;watch;create;update;patch;delete

func (r *PodsStartedReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	lg := ctrllog.FromContext(ctx)

	lg.V(3).Info("Reconciling Pod")

	var pod corev1.Pod
	if err := r.Get(ctx, req.NamespacedName, &pod); err != nil {
		if apierrors.IsNotFound(err) {
			// Don't requeue, Pod no longer exists.
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, fmt.Errorf("getting pod: %w", err)
	}

	if pod.GetDeletionTimestamp() != nil ||
		pod.Status.Phase == corev1.PodFailed || pod.Status.Phase == corev1.PodSucceeded {
		return ctrl.Result{}, nil
	}

	labels := pod.Labels
	if labels == nil {
		return ctrl.Result{}, nil
	}
	ann := pod.Annotations
	if ann == nil {
		return ctrl.Result{}, nil
	}

	const (
		// TODO: Determine annotation to use.
		startedThresholdAnn = "tbd.com/started-threshold"
		jobsetNameLabel     = "jobset.sigs.k8s.io/jobset-name"
		jobsetRestartLabel  = "jobset.sigs.k8s.io/restart-attempt"
	)

	startedThresholdStr, ok := ann[startedThresholdAnn]
	if !ok {
		return ctrl.Result{}, nil
	}
	startedThreshold, err := strconv.Atoi(startedThresholdStr)
	if err != nil {
		lg.Error(err, "failed to parse started-threshold as int", "value", startedThresholdStr)
		return ctrl.Result{}, nil
	}
	jobsetName, ok := labels[jobsetNameLabel]
	if !ok {
		return ctrl.Result{}, nil
	}
	jobsetRestart, ok := labels[jobsetRestartLabel]
	if !ok {
		return ctrl.Result{}, nil
	}

	// Assume the ConfigMap is present (created alongside the JobSet).
	// If the ConfigMap is set as an optional volume in the Pod spec
	// the propagation of a ConfigMap creation into container mount
	// appears to take a long time (>30s in a test).
	// NOTE: I guess we could still create the ConfigMap and have the user
	// specify the volume as required.
	cm := &corev1.ConfigMap{}
	if err := r.Get(ctx, types.NamespacedName{
		Namespace: req.Namespace,
		Name:      jobsetName + "-started-threshold",
	}, cm); err != nil {
		return ctrl.Result{}, fmt.Errorf("getting ConfigMap: %w", err)
	}
	if cm.Data == nil {
		cm.Data = map[string]string{}
	}
	if cm.Data["started"] == "true" {
		return ctrl.Result{}, nil
	}

	// List all Pods with the same labels
	var pods corev1.PodList
	if err := r.List(ctx, &pods, client.MatchingLabels{
		jobsetNameLabel:    jobsetName,
		jobsetRestartLabel: jobsetRestart,
	}); err != nil {
		return ctrl.Result{}, fmt.Errorf("listing pods: %w", err)
	}

	// TODO: See if it is possible to add an index to .status.startTime
	// to avoid the for loop.
	var startedCount int
	var thresholdMet bool
	for _, p := range pods.Items {
		if p.Status.StartTime != nil {
			startedCount++
			if startedCount >= startedThreshold {
				thresholdMet = true
				break
			}
		}
	}

	if !thresholdMet {
		return ctrl.Result{}, nil
	}

	// TODO: Set the owner reference to the JobSet?
	//jobsetOwner := unstructured.Unstructured{}
	//if err := ctrl.SetControllerReference(jobsetOwner, cm, r.Scheme); err != nil {
	//	return ctrl.Result{}, fmt.Errorf("setting owner reference: %w", err)
	//}

	cm.Data["started"] = "true"
	if err := r.Update(ctx, cm); err != nil {
		return ctrl.Result{}, fmt.Errorf("updating ConfigMap: %w", err)
	}

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *PodsStartedReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&corev1.Pod{}).
		Complete(r)
}
