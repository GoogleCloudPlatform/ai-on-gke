package controllertest

import (
	"context"

	"github.com/GoogleCloudPlatform/ai-on-gke/tpu-provisioner/internal/cloud"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"

	"sigs.k8s.io/controller-runtime/pkg/client"

	jobset "sigs.k8s.io/jobset/api/jobset/v1alpha2"
	jobsetconsts "sigs.k8s.io/jobset/pkg/constants"
)

// +kubebuilder:docs-gen:collapse=Imports

var _ = Describe("Deletion controller", func() {

	const defaultJobSetName = "test-jobset"

	var (
		jobSetCompletedStatus = &jobset.JobSetStatus{
			Conditions: []metav1.Condition{
				{
					Type:               string(jobset.JobSetCompleted),
					Status:             metav1.ConditionTrue,
					Reason:             jobsetconsts.AllJobsCompletedReason,
					Message:            jobsetconsts.AllJobsCompletedMessage,
					LastTransitionTime: metav1.Now(),
				},
			},
		}

		jobSetFailedStatus = &jobset.JobSetStatus{
			Conditions: []metav1.Condition{
				{
					Type:               string(jobset.JobSetFailed),
					Status:             metav1.ConditionTrue,
					Reason:             jobsetconsts.FailedJobsReason,
					Message:            jobsetconsts.FailedJobsMessage,
					LastTransitionTime: metav1.Now(),
				},
			},
		}
	)

	// A test case contains a node to reconcile, a JobSet which may or may not be related to that node,
	// and a boolean indicating if we expect a node pool deletion given this node and this JobSet.
	type testCase struct {
		node                 *corev1.Node
		jobSet               *jobset.JobSet
		jobSetStatus         *jobset.JobSetStatus
		wantNodePoolDeletion bool
	}

	DescribeTable("nodes are reconciled",
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

			// Clean up test node after each test case.
			defer func() {
				Expect(deleteNode(ctx, k8sClient, tc.node)).To(Succeed())
			}()

			// Update test Node's labels to use the test namespace.
			tc.node.Labels[cloud.LabelJobSetNamespace] = ns.Name

			// Create the jobset if needed for this test.
			if tc.jobSet != nil {
				// Set JobSet namespace as test namespace.
				tc.jobSet.Namespace = ns.Name

				By("Creating a JobSet")
				Expect(k8sClient.Create(ctx, tc.jobSet)).To(Succeed())
			}

			// Create the node.
			By("Creating a Node")
			Expect(k8sClient.Create(ctx, tc.node)).To(Succeed())

			// Update JobSet status if necessary.
			if tc.jobSetStatus != nil {
				updateJobSetStatus(ctx, k8sClient, tc.jobSet, tc.jobSetStatus)
			}

			// Check node pool deletion calls made were expected.
			if tc.wantNodePoolDeletion {
				assertNodePoolDeletionTriggered(tc.node)
			} else {
				assertNodePoolDeletionNotTriggered(tc.node)
			}
		},
		// Test cases.
		Entry("node managed by provisioner and jobset no longer exists, node pool should be deleted", &testCase{
			node: makeNodeWithLabels("node1", map[string]string{
				cloud.LabelNodepoolManager: cloud.LabelNodepoolManagerTPUPodinator,
				cloud.GKENodePoolNameLabel: "test-nodepool-1",
				cloud.LabelJobSetName:      defaultJobSetName,
			}),
			wantNodePoolDeletion: true,
		}),
		Entry("node managed by provisioner and jobset still exists, node pool should not be deleted", &testCase{
			node: makeNodeWithLabels("node2", map[string]string{
				cloud.LabelNodepoolManager: cloud.LabelNodepoolManagerTPUPodinator,
				cloud.GKENodePoolNameLabel: "test-nodepool-1",
				cloud.LabelJobSetName:      defaultJobSetName,
			}),
			jobSet: makeJobSet(defaultJobSetName),
		}),
		Entry("node managed by provisioner and jobset is completed, node pool should be deleted", &testCase{
			node: makeNodeWithLabels("node3", map[string]string{
				cloud.LabelNodepoolManager: cloud.LabelNodepoolManagerTPUPodinator,
				cloud.GKENodePoolNameLabel: "test-nodepool-1",
				cloud.LabelJobSetName:      defaultJobSetName,
			}),
			jobSet:               makeJobSet(defaultJobSetName),
			jobSetStatus:         jobSetCompletedStatus,
			wantNodePoolDeletion: true,
		}),
		Entry("node managed by provisioner and jobset is failed, node pool should be deleted", &testCase{
			node: makeNodeWithLabels("node4", map[string]string{
				cloud.LabelNodepoolManager: cloud.LabelNodepoolManagerTPUPodinator,
				cloud.GKENodePoolNameLabel: "test-nodepool-1",
				cloud.LabelJobSetName:      defaultJobSetName,
			}),
			jobSet:               makeJobSet(defaultJobSetName),
			jobSetStatus:         jobSetFailedStatus,
			wantNodePoolDeletion: true,
		}),
	)
})

// assertNodePoolDeletionTriggered validates that the given pod did trigger a node pool
// deletion by checking that we eventually see the provider make a node pool deletion attempt.
func assertNodePoolDeletionTriggered(node *corev1.Node) {
	Eventually(func() bool {
		_, deleted := provider.getDeleted(node.Name)
		return deleted
	}, timeout, interval).Should(BeTrue())
}

// assertNodePoolDeletionNotTriggered validates that the given pod did not trigger a node pool
// deletion by checking that we consistently see the provider has made no node pool deletion attempts
// for thet given pod.
func assertNodePoolDeletionNotTriggered(node *corev1.Node) {
	Consistently(func() bool {
		_, deleted := provider.getDeleted(node.Name)
		return deleted
	}, timeout, interval).Should(BeFalse())
}

// makeNodeWithLabels returns a Node object with the given name and labels.
func makeNodeWithLabels(name string, labels map[string]string) *corev1.Node {
	return &corev1.Node{
		ObjectMeta: metav1.ObjectMeta{
			Name:   name,
			Labels: labels,
		},
		Spec: corev1.NodeSpec{},
	}
}

// makeJobSet returns an empty JobSet with the given name and namespace.
func makeJobSet(name string) *jobset.JobSet {
	return &jobset.JobSet{
		ObjectMeta: metav1.ObjectMeta{
			Name: name,
		},
		Spec: jobset.JobSetSpec{
			ReplicatedJobs: []jobset.ReplicatedJob{},
			Network:        &jobset.Network{},
		},
	}
}

func updateJobSetStatus(ctx context.Context, k8sClient client.Client, js *jobset.JobSet, status *jobset.JobSetStatus) {
	// Fetch latest JobSet resource version so we don't get an operation conflict.
	var createdJS jobset.JobSet
	Eventually(func() error {
		return k8sClient.Get(ctx, types.NamespacedName{Name: js.Name, Namespace: js.Namespace}, &createdJS)
	}, timeout, interval).Should(Succeed())

	By("Updating JobSet status")
	createdJS.Status = *status
	Eventually(func() error {
		return k8sClient.Status().Update(ctx, &createdJS)
	}, timeout, interval).Should(Succeed())
}

func deleteNode(ctx context.Context, k8sClient client.Client, node *corev1.Node) error {
	if node == nil {
		return nil
	}
	if err := k8sClient.Delete(ctx, node, client.PropagationPolicy(metav1.DeletePropagationForeground)); err != nil && !apierrors.IsNotFound(err) {
		return err
	}
	return nil
}
