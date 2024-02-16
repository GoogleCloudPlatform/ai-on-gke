package controller

import (
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
