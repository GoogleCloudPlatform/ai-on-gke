package cloud

import (
	"errors"

	corev1 "k8s.io/api/core/v1"
)

type Provider interface {
	NodePoolLabelKey() string
	EnsureNodePoolForPod(*corev1.Pod) error
	DeleteNodePoolForNode(*corev1.Node) error
}

var ErrDuplicateRequest = errors.New("duplicate request")
