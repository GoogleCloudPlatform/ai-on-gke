package controllertest

import (
	"sync"
	"time"

	"github.com/GoogleCloudPlatform/ai-on-gke/tpu-provisioner/internal/cloud"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/types"
)

var _ cloud.Provider = &mockProvider{}

type mockProvider struct {
	sync.Mutex
	created map[types.NamespacedName]bool
	deleted map[string]time.Time

	cloud.Provider
}

func (p *mockProvider) NodePoolLabelKey() string { return cloud.GKENodePoolNameLabel }

func (p *mockProvider) EnsureNodePoolForPod(pod *corev1.Pod, _ string) error {
	p.Lock()
	defer p.Unlock()
	p.created[types.NamespacedName{Namespace: pod.Namespace, Name: pod.Name}] = true
	return nil
}

func (p *mockProvider) getCreated(nn types.NamespacedName) bool {
	p.Lock()
	defer p.Unlock()
	return p.created[nn]
}

func (p *mockProvider) DeleteNodePoolForNode(node *corev1.Node, _ string) error {
	p.Lock()
	defer p.Unlock()
	if _, exists := p.deleted[node.Name]; !exists {
		p.deleted[node.Name] = time.Now()
	}
	return nil
}

func (p *mockProvider) getDeleted(name string) (time.Time, bool) {
	p.Lock()
	defer p.Unlock()
	timestamp, exists := p.deleted[name]
	return timestamp, exists
}
