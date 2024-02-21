package controller

import (
	"context"
	"fmt"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	corev1 "k8s.io/api/core/v1"
	apires "k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
)

// +kubebuilder:docs-gen:collapse=Imports

var _ = Describe("Creation controller", func() {

	// Define utility constants for object names and testing timeouts/durations and intervals.
	const (
		timeout  = time.Second * 10
		duration = time.Second * 10
		interval = time.Millisecond * 250
	)

	Context("When watching Pods", func() {
		It("Should create a Node Pool when expected", func() {
			ctx := context.Background()

			By("Creating a non-pending Pod")

			ignoreMePod := corev1.Pod{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "should-not-trigger-node-pool-creation",
					Namespace: "default",
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  "test",
							Image: "test",
						},
					},
				},
			}
			Expect(k8sClient.Create(ctx, &ignoreMePod)).Should(Succeed())

			By("Creating a to-be pending Pod")

			targetPod := corev1.Pod{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "should-trigger-node-pool-creation",
					Namespace: "default",
				},
				Spec: corev1.PodSpec{
					NodeSelector: map[string]string{
						"test-key":                          "test-val",
						"cloud.google.com/gke-tpu-topology": "2x2x4",
					},
					Containers: []corev1.Container{
						{
							Name:  "test",
							Image: "test",
							Resources: corev1.ResourceRequirements{
								Limits: map[corev1.ResourceName]apires.Quantity{
									corev1.ResourceName(resourceName): {
										Format: "1",
									},
								},
								Requests: map[corev1.ResourceName]apires.Quantity{
									corev1.ResourceName(resourceName): {
										Format: "2",
									},
								},
							},
						},
					},
				},
			}
			Expect(k8sClient.Create(ctx, &targetPod)).Should(Succeed())

			By("Getting the created Pod in order to update its status")

			var createdTargetPod corev1.Pod
			Eventually(func() error {
				nn := types.NamespacedName{Name: targetPod.Name, Namespace: targetPod.Namespace}
				return k8sClient.Get(ctx, nn, &createdTargetPod)
			}, timeout, interval).Should(Succeed())

			createdTargetPod.Status = corev1.PodStatus{
				Phase: corev1.PodPending,
				Conditions: []corev1.PodCondition{
					{
						Type:               corev1.PodScheduled,
						Status:             corev1.ConditionFalse,
						Reason:             corev1.PodReasonUnschedulable,
						LastProbeTime:      metav1.Time{Time: time.Now()},
						LastTransitionTime: metav1.Time{Time: time.Now()},
						Message:            fmt.Sprintf("0/3 nodes are available: 3 Insufficient %s.", resourceName),
					},
				},
			}

			By("Updating the created Pod to simulate a pending status")
			Expect(k8sClient.Status().Update(ctx, &createdTargetPod)).Should(Succeed())

			By("Checking that a Node Pool creation attempt was made")
			// Ensure the pending Pod resulted in a Node Pool creation attempt.
			Eventually(func() bool {
				return provider.getCreated(types.NamespacedName{Name: targetPod.Name, Namespace: targetPod.Namespace})
			}, timeout, interval).Should(BeTrue())

			By("Checking that excessive Node Pool creation attempts were not made")
			// Ensure the non-pending Pod did not result in a Node Pool creation attempt.
			Consistently(func() bool {
				return provider.getCreated(types.NamespacedName{Name: ignoreMePod.Name, Namespace: ignoreMePod.Namespace})
			}, timeout, interval).Should(BeFalse())
		})
	})

})
