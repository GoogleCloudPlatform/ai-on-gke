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
	"errors"
	"fmt"
	"time"

	"github.com/GoogleCloudPlatform/ai-on-gke/tpu-provisioner/internal/cloud"

	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/client-go/tools/record"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	ctrllog "sigs.k8s.io/controller-runtime/pkg/log"
)

// CreationReconciler watches Pods and creates Node Pools.
type CreationReconciler struct {
	client.Client
	Scheme   *runtime.Scheme
	Recorder record.EventRecorder

	PodCriteria PodCriteria

	Provider cloud.Provider
}

type PodCriteria struct {
	ResourceType string
}

//+kubebuilder:rbac:groups="",resources=pods,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups="",resources=pods/status,verbs=get;update;patch
//+kubebuilder:rbac:groups="",resources=pods/finalizers,verbs=update

func (r *CreationReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
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

	// Return early if Pod should not trigger a scale up.
	if !isPending(&pod) || !isUnschedulable(&pod) ||
		!doesRequestResource(&pod, r.PodCriteria.ResourceType) ||
		!hasNodeSelectors(&pod, cloud.GKETPUNodeSelector) ||
		pod.DeletionTimestamp != nil {
		lg.V(3).Info("Ignoring pod")
		return ctrl.Result{}, nil
	}

	lg.Info("Ensuring node pool for unschedulable pod")
	if err := r.Provider.EnsureNodePoolForPod(&pod, "pod is currently unschedulable"); err != nil {
		if errors.Is(err, cloud.ErrDuplicateRequest) {
			lg.Info("Ignoring duplicate request to create node pool")
		} else if errors.Is(err, cloud.ErrNodePoolStopping) {
			wait := 5 * time.Second
			lg.Info("Attempted to create a node pool that is currently undergoing deletion, retrying soon",
				"wait", wait)
			return ctrl.Result{RequeueAfter: wait}, nil
		} else {
			return ctrl.Result{}, err
		}
	}

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *CreationReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&corev1.Pod{}).
		Complete(r)
}
