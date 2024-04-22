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
	"time"

	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/client-go/tools/record"
	"k8s.io/utils/ptr"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	ctrllog "sigs.k8s.io/controller-runtime/pkg/log"
	jobset "sigs.k8s.io/jobset/api/jobset/v1alpha2"
)

const (
	jobsetNameLabel             = "jobset.sigs.k8s.io/jobset-name"
	jobsetRestartLabel          = "jobset.sigs.k8s.io/restart-attempt"
	jobsetSyncedStartAnnotation = "alpha.jobset.sigs.k8s.io/synced-start-configmap"
	allStartedConfigMapKey      = "all-started"
)

// SyncedStartReconciler watches Pods and updates a ConfigMap when a minimum number of
// associated Pods have started.
// It assumes that these Pods are managed by a JobSet, otherwise it will ignore them.
// The threshold is set via an annotation and is intended to be the total number of Pods
// in the JobSet - allowing for semi-synchronous startup across an entire JobSet.
// This threshold annotation is used to avoid a lookup of the number of replicas in the JobSet.
type SyncedStartReconciler struct {
	client.Client
	Scheme   *runtime.Scheme
	Recorder record.EventRecorder
}

//+kubebuilder:rbac:groups="",resources=configmaps,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups="jobset.x-k8s.io",resources=jobsets,verbs=get;list;watch

func (r *SyncedStartReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	lg := ctrllog.FromContext(ctx)

	lg.V(3).Info("Reconciling JobSet")

	js := &jobset.JobSet{}
	if err := r.Get(ctx, req.NamespacedName, js); err != nil {
		if apierrors.IsNotFound(err) {
			// Don't requeue, no longer exists.
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, fmt.Errorf("getting jobset: %w", err)
	}

	if js.GetDeletionTimestamp() != nil {
		return ctrl.Result{}, nil
	}

	if js.Annotations == nil {
		return ctrl.Result{}, nil
	}
	configMapName := js.Annotations[jobsetSyncedStartAnnotation]
	if configMapName == "" {
		return ctrl.Result{}, nil
	}

	// NOTE: If the ConfigMap is set as an optional volume in the Pod spec
	// the propagation of a ConfigMap creation into container mount
	// appears to take a long time (>30s in a test).
	cm := &corev1.ConfigMap{}
	if err := r.Get(ctx, types.NamespacedName{
		Namespace: req.Namespace,
		Name:      configMapName,
	}, cm); err != nil {
		if apierrors.IsNotFound(err) {
			// Create ConfigMap if it did not exist.
			cm = &corev1.ConfigMap{
				ObjectMeta: metav1.ObjectMeta{
					Name:      configMapName,
					Namespace: req.Namespace,
				},
			}
			if err := ctrl.SetControllerReference(js, cm, r.Scheme); err != nil {
				return ctrl.Result{}, fmt.Errorf("setting owner reference: %w", err)
			}
			if err := r.Create(ctx, &corev1.ConfigMap{
				ObjectMeta: metav1.ObjectMeta{
					Name:      configMapName,
					Namespace: req.Namespace,
				},
			}); err != nil {
				if apierrors.IsAlreadyExists(err) {
					// Reconcile again and hopefully the cache will be updated
					// by then, allowing the .Get() to succeed. Then the reconcile
					// should progress to the subsequent steps. This check avoids noisy
					// and unactionable errors being logged.
					return ctrl.Result{Requeue: true}, nil
				}
				return ctrl.Result{}, fmt.Errorf("creating ConfigMap: %w", err)
			}
		}
		return ctrl.Result{}, fmt.Errorf("getting ConfigMap: %w", err)
	}

	if cm.Data == nil {
		cm.Data = map[string]string{}
	}

	// If the ConfigMap has already been updated, return early.
	if cm.Data[allStartedConfigMapKey] == "true" {
		return ctrl.Result{}, nil
	}

	// List all Pods in the current restart of the JobSet.
	var pods corev1.PodList
	if err := r.List(ctx, &pods, client.MatchingLabels{
		jobsetNameLabel:    js.Name,
		jobsetRestartLabel: strconv.Itoa(int(js.Status.Restarts)),
	}); err != nil {
		return ctrl.Result{}, fmt.Errorf("listing pods: %w", err)
	}

	threshold, ok := startedThreshold(js)
	if !ok {
		return ctrl.Result{}, nil
	}

	// TODO: See if it is possible to add an index to .status.startTime
	// to avoid the for loop.
	var startedCount int32
	var thresholdMet bool
	for _, p := range pods.Items {
		if p.Status.StartTime != nil {
			startedCount++
			if startedCount >= threshold {
				thresholdMet = true
				break
			}
		}
	}

	if !thresholdMet {
		// Check again soon. We use polling to avoid needing
		// to reconcile based on Pods which would be more noisy.
		return ctrl.Result{RequeueAfter: time.Second}, nil
	}

	// Update the ConfigMap to indicate that all Pods have started.
	cm.Data[allStartedConfigMapKey] = "true"
	if err := r.Update(ctx, cm); err != nil {
		return ctrl.Result{}, fmt.Errorf("updating ConfigMap: %w", err)
	}

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *SyncedStartReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&jobset.JobSet{}).
		Complete(r)
}

func startedThreshold(js *jobset.JobSet) (int32, bool) {
	cmName := js.Annotations[jobsetSyncedStartAnnotation]

	var (
		n     int32
		found bool
	)

	for _, rj := range js.Spec.ReplicatedJobs {
		for _, v := range rj.Template.Spec.Template.Spec.Volumes {
			if v.ConfigMap != nil && v.ConfigMap.Name == cmName {
				found = true
				n += rj.Replicas * ptr.Deref(rj.Template.Spec.Parallelism, 1)
			}
		}
	}

	return n, found
}
