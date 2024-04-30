package webhooks

import (
	"context"
	"fmt"

	batchv1 "k8s.io/api/batch/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	ctrllog "sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/webhook/admission"

	jobset "sigs.k8s.io/jobset/api/jobset/v1alpha2"
)

// +kubebuilder:webhook:path=/mutate--v1-pod,mutating=true,failurePolicy=fail,groups="",resources=pods,verbs=create,versions=v1,name=mpod.kb.io,sideEffects=None,admissionReviewVersions=v1

// jobWebhook for mutating webhook.
type jobWebhook struct {
	client  client.Client
	decoder *admission.Decoder
}

func NewJobWebhook(client client.Client) *jobWebhook {
	return &jobWebhook{client: client}
}

// SetupWebhookWithManager configures the mutating webhook for pods.
func (j *jobWebhook) SetupJobWebhookWithManager(mgr ctrl.Manager) error {
	return ctrl.NewWebhookManagedBy(mgr).
		For(&batchv1.Job{}).
		WithDefaulter(j).
		Complete()
}

// InjectDecoder injects the decoder into the jobWebhook.
func (j *jobWebhook) InjectDecoder(d *admission.Decoder) error {
	j.decoder = d
	return nil
}

// Default applies mutations to Jobs which are part of a JobSet.
func (j *jobWebhook) Default(ctx context.Context, obj runtime.Object) error {
	job, ok := obj.(*batchv1.Job)
	if !ok || !partOfJobSet(job) {
		return nil
	}
	return j.setNodeSelector(ctx, job)
}

// setNodeSelector sets a nodeSelector of "jobset.sigs.k8s.io/job-key=<job key>"
// on the Job template spec, to ensure a Job has exclusive usage of the node pool
// provisioned for it, and there's no swapping of Jobs between node pools during
// JobSet restarts.
func (j *jobWebhook) setNodeSelector(ctx context.Context, job *batchv1.Job) error {
	lg := ctrllog.FromContext(ctx)
	template := job.Spec.Template
	if template.Spec.NodeSelector == nil {
		template.Spec.NodeSelector = make(map[string]string)
	}
	jobKey, exists := job.Annotations[jobset.JobKey]
	if !exists {
		return fmt.Errorf("job %s missing annotation %s", job.Name, jobset.JobKey)
	}
	template.Spec.NodeSelector[jobset.JobKey] = jobKey
	lg.V(5).Info("job %s set node selector %s=%s", job.Name, jobset.JobKey, jobKey)
	return nil
}

// partOfJobSet returns a true if the Job is part of a JobSet,
// otherwise it returns false.
func partOfJobSet(job *batchv1.Job) bool {
	return job.Annotations[jobset.JobSetNameKey] != ""
}
