package controller

import (
	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"
)

func isPending(p *corev1.Pod) bool {
	return p.Status.Phase == corev1.PodPending
}

func isDone(p *corev1.Pod) bool {
	return p.Status.Phase == corev1.PodSucceeded || p.Status.Phase == corev1.PodFailed
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

func doesRequestResource(p *corev1.Pod, resource string) bool {
	for _, c := range p.Spec.Containers {
		if _, ok := c.Resources.Requests[corev1.ResourceName(resource)]; ok {
			return true
		}
	}
	return false
}

func hasNodeSelectors(p *corev1.Pod, selectors ...string) bool {
	for _, key := range selectors {
		if _, ok := p.Spec.NodeSelector[key]; !ok {
			return false
		}
	}
	return true
}

// podDeleted returns true if hte pod has been marked for deletion, otherwise it returns false.
func podDeleted(pod *corev1.Pod) bool {
	return pod.DeletionTimestamp != nil
}

// partOfJobSet returns true if the pod is part of a JobSet, otherwise it returns false.
func partOfJobSet(pod *corev1.Pod) bool {
	// Annotation is from here:
	// https://github.com/kubernetes-sigs/jobset/blob/6343f09b8a1851090586d0efca16c6ab68982318/api/jobset/v1alpha2/jobset_types.go#L23
	return pod.Annotations["jobset.sigs.k8s.io/jobset-name"] != ""
}

// isLeaderPod returns true if the given pod is a leader pod (job completion index of 0),
// otherwise it returns false.
func isLeaderPod(pod *corev1.Pod) bool {
	return pod.Annotations[batchv1.JobCompletionIndexAnnotation] == "0"
}

// autoProvisioningDisabled returns true if the pod has
// "tpu-provisioner.cloud.google.com/disable-autoprovisioning=true"
// set as a label or annotation. Otherwise, it returns false.
func autoProvisioningDisabled(pod *corev1.Pod) bool {
	return pod.Labels[DisableAutoProvisioningLabel] == "true" || pod.Annotations[DisableAutoProvisioningLabel] == "true"
}
