package controllertest

import (
	"context"
	"fmt"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	apires "k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
	"sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/GoogleCloudPlatform/ai-on-gke/tpu-provisioner/internal/controller"
)

// +kubebuilder:docs-gen:collapse=Imports

var _ = Describe("Creation controller", func() {

	// A test case contains a pod to create, the status we will update it to have, and whether or not
	// we expect this pod to trigger a node pool creation.
	type testCase struct {
		pod                  *corev1.Pod
		status               *corev1.PodStatus
		wantNodePoolCreation bool
	}

	DescribeTable("pods are created and go through a status update",
		// Logic for each test case.
		func(tc *testCase) {
			ctx := context.Background()
			// Create test namespace for each entry to isolate each test case.
			ns := &corev1.Namespace{
				ObjectMeta: metav1.ObjectMeta{
					GenerateName: "test-ns-",
				},
			}
			Expect(k8sClient.Create(ctx, ns)).To(Succeed())

			// Clean up temporary namespace after each test case.
			defer func() {
				Expect(deleteNamespace(ctx, k8sClient, ns)).To(Succeed())
			}()

			// Create pod in test namespace.
			pod := tc.pod
			pod.Namespace = ns.Name

			By(fmt.Sprintf("Creating pod %s", pod.Name))
			Expect(k8sClient.Create(ctx, pod)).To(Succeed())

			// Perform pod status update if required.
			if tc.status != nil {
				updatePodStatus(ctx, k8sClient, pod, *tc.status)
			}

			// Check node pool creation attempts.
			if tc.wantNodePoolCreation {
				By("Checking that the pod triggered a node pool creation attempt")
				assertNodePoolCreationTriggered(pod)
			} else {
				By("Checking that pod did not trigger a node pool creation attempt")
				assertNodePoolCreationNotTriggered(pod)
			}
		},
		// Test cases.
		Entry("pending leader pod should trigger node pool creation", &testCase{
			pod:                  makeLeaderPod(),
			status:               makePendingStatus(),
			wantNodePoolCreation: true,
		}),
		Entry("non-pending leader pod should not trigger node pool creation", &testCase{
			pod:    makeLeaderPod(),
			status: makeRunningStatus(),
		}),
		Entry("pending follower pod should not trigger node pool creation", &testCase{
			pod:    makeFollowerPod(),
			status: makePendingStatus(),
		}),
		Entry("non-pending follower pod should not trigger node pool creation", &testCase{
			pod:    makeFollowerPod(),
			status: makeRunningStatus(),
		}),
		Entry("pending leader pod with auto provisioned disabled annotation should not trigger node pool creation", &testCase{
			pod:    makeLeaderPodAutoProvisioningDisabled(),
			status: makePendingStatus(),
		}),
	)
})

func makeLeaderPod() *corev1.Pod {
	return makePod(&makePodArgs{name: "leader-pod", completionIndex: "0"})
}

func makeFollowerPod() *corev1.Pod {
	return makePod(&makePodArgs{name: "follower-pod", completionIndex: "1"})
}

func makeLeaderPodAutoProvisioningDisabled() *corev1.Pod {
	leaderPod := makeLeaderPod()
	leaderPod.Annotations[controller.DisableAutoProvisioningLabel] = "true"
	return leaderPod
}

// makePendingStatus returns a pod status indicating it became unschedulable at the given time.
func makePendingStatus() *corev1.PodStatus {
	lastTransitionTime := metav1.Now()
	return &corev1.PodStatus{
		Phase: corev1.PodPending,
		Conditions: []corev1.PodCondition{
			{
				Type:               corev1.PodScheduled,
				Status:             corev1.ConditionFalse,
				Reason:             corev1.PodReasonUnschedulable,
				LastProbeTime:      lastTransitionTime,
				LastTransitionTime: lastTransitionTime,
				Message:            fmt.Sprintf("0/3 nodes are available: 3 Insufficient %s.", resourceName),
			},
		},
	}
}

// makeRunningStatus returns a pod status indicating it started running at the given time.
func makeRunningStatus() *corev1.PodStatus {
	lastTransitionTime := metav1.Now()
	return &corev1.PodStatus{
		Phase: corev1.PodPending,
		Conditions: []corev1.PodCondition{
			{
				Type:               corev1.PodScheduled,
				Status:             corev1.ConditionTrue,
				Reason:             corev1.PodReasonUnschedulable,
				LastProbeTime:      lastTransitionTime,
				LastTransitionTime: lastTransitionTime,
			},
		},
	}
}

// updatePodStatus updates the pod status and verifies the status update request eventually succeeds.
func updatePodStatus(ctx context.Context, k8sClient client.Client, pod *corev1.Pod, status corev1.PodStatus) {
	// Fetch the created pod with latest resource version to update its status.
	var createdPod corev1.Pod
	Eventually(func() error {
		nn := types.NamespacedName{Name: pod.Name, Namespace: pod.Namespace}
		return k8sClient.Get(ctx, nn, &createdPod)
	}, timeout, interval).Should(Succeed())

	By(fmt.Sprintf("Updating the pod status to %s", status.Phase))
	createdPod.Status = status
	Expect(k8sClient.Status().Update(ctx, &createdPod)).Should(Succeed())
}

// assertNodePoolCreationTriggered validates that the given pod did trigger a node pool
// creation by checking that we eventually see the provider make a node pool creation attempt.
func assertNodePoolCreationTriggered(pod *corev1.Pod) {
	Eventually(func() bool {
		return provider.getCreated(types.NamespacedName{Name: pod.Name, Namespace: pod.Namespace})
	}, timeout, interval).Should(BeTrue())
}

// assertNodePoolCreationNotTriggered validates that the given pod did not trigger a node pool
// creation by checking that we consistently see the provider has made no node pool creation attempts
// for thet given pod.
func assertNodePoolCreationNotTriggered(pod *corev1.Pod) {
	Consistently(func() bool {
		return provider.getCreated(types.NamespacedName{Name: pod.Name, Namespace: pod.Namespace})
	}, timeout, interval).Should(BeFalse())
}

// // deleteNamespace deletes the namespace and all the objects in it.
func deleteNamespace(ctx context.Context, c client.Client, ns *corev1.Namespace) error {
	if ns == nil {
		return nil
	}
	if err := c.Delete(ctx, ns, client.PropagationPolicy(metav1.DeletePropagationForeground)); err != nil && !apierrors.IsNotFound(err) {
		return err
	}
	return nil
}

type makePodArgs struct {
	name              string
	completionIndex   string
	deletionTimestamp *metav1.Time
}

func makePod(args *makePodArgs) *corev1.Pod {
	return &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name: args.name,
			Annotations: map[string]string{
				"jobset.sigs.k8s.io/jobset-name":     "test-js",
				batchv1.JobCompletionIndexAnnotation: args.completionIndex,
			},
			DeletionTimestamp: args.deletionTimestamp,
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
}
