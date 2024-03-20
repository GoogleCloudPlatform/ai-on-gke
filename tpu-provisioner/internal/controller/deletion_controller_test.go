package controller

import (
	"context"
	"time"

	"github.com/GoogleCloudPlatform/ai-on-gke/tpu-provisioner/internal/cloud"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
)

// +kubebuilder:docs-gen:collapse=Imports

var _ = Describe("Deletion controller", func() {

	// Define utility constants for object names and testing timeouts/durations and intervals.
	const (
		timeout  = time.Second * 10
		duration = time.Second * 10
		interval = time.Millisecond * 250
	)

	Context("When watching Nodes", func() {
		It("Should delete a Node Pool when expected", func() {
			ctx := context.Background()

			By("Creating a Node that should be ignored")
			ignoreMeNode := corev1.Node{
				ObjectMeta: metav1.ObjectMeta{
					Name: "should-not-trigger-node-pool-deletion",
				},
				Spec: corev1.NodeSpec{},
			}
			Expect(k8sClient.Create(ctx, &ignoreMeNode)).Should(Succeed())

			By("Creating a Node that should trigger a Node Pool deletion")
			targetNode := corev1.Node{
				ObjectMeta: metav1.ObjectMeta{
					Name: "should-trigger-node-pool-deletion",
					Labels: map[string]string{
						cloud.LabelNodepoolManager:     cloud.LabelNodepoolManagerTPUPodinator,
						"cloud.test.com/test-nodepool": "test-nodepool-1",
					},
				},
				Spec: corev1.NodeSpec{},
			}
			Expect(k8sClient.Create(ctx, &targetNode)).Should(Succeed())

			// Fetch the created Node object to get the creation timestamp.
			var createdNode corev1.Node
			Eventually(func() error {
				return k8sClient.Get(ctx, types.NamespacedName{Name: targetNode.Name, Namespace: targetNode.Namespace}, &createdNode)
			}, timeout, interval).Should(Succeed())

			By("Checking that the target Node triggered a Node Pool deletion attempt")
			var deletionTimestamp time.Time
			Eventually(func() bool {
				timestamp, deleted := provider.getDeleted(targetNode.Name)
				if deleted {
					deletionTimestamp = timestamp
				}
				return deleted
			}, timeout, interval).Should(BeTrue())

			By("Checking the first deletion attempt only occurred after the node had existed for >= nodeDeletionInterval")
			actualDuration := deletionTimestamp.Sub(createdNode.CreationTimestamp.Time)
			requiredDuration := nodepoolDeletionDelay + minNodeLifetime
			Expect(actualDuration).Should(BeNumerically(">=", requiredDuration))

			By("Checking that other Nodes were ignored")
			Consistently(func() bool {
				_, deleted := provider.getDeleted(ignoreMeNode.Name)
				return deleted
			}, timeout, interval).Should(BeFalse())
		})
	})
})
