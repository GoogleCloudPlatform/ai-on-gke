package webhooks

import (
	"context"
	"fmt"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/webhook/admission"
)

const (
	jobNameKey = "tpu.provisioner.io/job-name"

	// jobSetNameKey is defined here: https://github.com/kubernetes-sigs/jobset/blob/cb941fcee597d1ff7002e7fca7a736a264ed6f6f/api/jobset/v1alpha2/jobset_types.go#L23
	jobSetNameKey = "jobset.sigs.k8s.io/jobset-name"
)

// +kubebuilder:webhook:path=/mutate--v1-pod,mutating=true,failurePolicy=fail,groups="",resources=pods,verbs=create,versions=v1,name=mpod.kb.io,sideEffects=None,admissionReviewVersions=v1

// podWebhook for mutating webhook.
type podWebhook struct {
	client  client.Client
	decoder *admission.Decoder
}

func NewPodWebhook(client client.Client) *podWebhook {
	return &podWebhook{client: client}
}

// SetupWebhookWithManager configures the mutating webhook for pods.
func (p *podWebhook) SetupPodWebhookWithManager(mgr ctrl.Manager) error {
	return ctrl.NewWebhookManagedBy(mgr).
		For(&corev1.Pod{}).
		WithDefaulter(p).
		Complete()
}

// InjectDecoder injects the decoder into the podWebhook.
func (p *podWebhook) InjectDecoder(d *admission.Decoder) error {
	p.decoder = d
	return nil
}

// Default will mutate pods being created by injecting the following nodeSelector:
// 1. pod
func (p *podWebhook) Default(ctx context.Context, obj runtime.Object) error {
	pod, ok := obj.(*corev1.Pod)
	if !ok || !partOfJobSet(pod) {
		return nil
	}
	return p.setNodeSelector(ctx, pod)
}

// setNodeSelector sets a nodeSelector of "tpu.provisioner.io/job-name=<job name>"
// on the pod, to ensure a Job has exclusive usage of the node pool provisioned for it,
// and there's no swapping of Jobs between node pools during JobSet restarts.
func (p *podWebhook) setNodeSelector(ctx context.Context, pod *corev1.Pod) error {
	if pod.Spec.NodeSelector == nil {
		pod.Spec.NodeSelector = make(map[string]string)
	}
	owner := metav1.GetControllerOf(pod)
	if owner != nil {
		return fmt.Errorf("owner ref not found")
	}
	pod.Spec.NodeSelector[jobNameKey] = owner.Name
	return nil
}

// partOfJobSet returns a true if the pod is part of a JobSet,
// otherwise it returns false.
func partOfJobSet(pod *corev1.Pod) bool {
	return pod.Annotations[jobSetNameKey] != ""
}
