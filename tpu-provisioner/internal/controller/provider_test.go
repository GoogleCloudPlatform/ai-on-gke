package controller

import (
	"sync"
	"time"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/types"
)

type testProvider struct {
	sync.Mutex
	created map[types.NamespacedName]bool
	deleted map[string]time.Time
}

func (p *testProvider) NodePoolLabelKey() string { return "cloud.test.com/test-nodepool" }

func (p *testProvider) EnsureNodePoolForPod(pod *corev1.Pod) error {
	p.Lock()
	defer p.Unlock()
	p.created[types.NamespacedName{Namespace: pod.Namespace, Name: pod.Name}] = true
	return nil
}

func (p *testProvider) getCreated(nn types.NamespacedName) bool {
	p.Lock()
	defer p.Unlock()
	return p.created[nn]
}

func (p *testProvider) DeleteNodePoolForNode(node *corev1.Node) error {
	p.Lock()
	defer p.Unlock()
	if _, exists := p.deleted[node.Name]; !exists {
		p.deleted[node.Name] = time.Now()
	}
	return nil
}

func (p *testProvider) getDeleted(name string) (time.Time, bool) {
	p.Lock()
	defer p.Unlock()
	timestamp, exists := p.deleted[name]
	return timestamp, exists
}
