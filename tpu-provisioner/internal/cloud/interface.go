package cloud

import (
	"errors"
	"time"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/types"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

type Provider interface {
	NodePoolLabelKey() string
	EnsureNodePoolForPod(*corev1.Pod, string) error
	DeleteNodePoolForNode(*corev1.Node, string) error
	DeleteNodePool(string, client.Object, string) error
	ListNodePools() ([]NodePoolRef, error)
}

var ErrDuplicateRequest = errors.New("duplicate request")

type NodePoolRef struct {
	Name string

	CreationTime time.Time

	CreatedForPod types.NamespacedName

	Error    bool
	ErrorMsg string
}
