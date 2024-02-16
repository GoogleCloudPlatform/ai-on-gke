package cloud

import corev1 "k8s.io/api/core/v1"

// Mock is useful for local development or debugging purposes to understand what
// the controller would do without it doing anything.
type Mock struct{}

// TODO: Find a better mock node pool label key.
func (m *Mock) NodePoolLabelKey() string                 { return "kubernetes.io/os" }
func (m *Mock) EnsureNodePoolForPod(*corev1.Pod) error   { return nil }
func (m *Mock) DeleteNodePoolForNode(*corev1.Node) error { return nil }
