package integration

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"time"

	"sigs.k8s.io/controller-runtime/pkg/client"
	jobsetv1a "sigs.k8s.io/jobset/api/jobset/v1alpha2"

	v1 "github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/api/v1"
	"github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/internal/actions"
	"github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/internal/server"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/uuid"
	"k8s.io/client-go/tools/record"
)

// mockGCPInstanceManager implements the GCPInstanceManager interface for testing
type mockGCPInstanceManager struct {
	deletedInstances []deletedInstance
}

type deletedInstance struct {
	project string
	zone    string
	name    string
}

func (m *mockGCPInstanceManager) DeleteInstance(ctx context.Context, project, zone, instance string) error {
	m.deletedInstances = append(m.deletedInstances, deletedInstance{project, zone, instance})
	return nil
}

var _ = Describe("Server Integration", func() {
	const testNamespace = "default"
	var (
		srv            *server.Server
		actionTaker    *actions.ActionTaker
		gcpMock        *mockGCPInstanceManager
		nodePool       string
		testJobSetName string
		rec            record.EventRecorder
	)

	// Helper function to send an action request and get the response
	sendActionRequest := func(req v1.ActionRequest) (v1.ActionResponse, int, error) {
		reqBody, err := json.Marshal(req)
		Expect(err).NotTo(HaveOccurred())

		w := httptest.NewRecorder()
		r := httptest.NewRequest(http.MethodPost, "/actions", bytes.NewReader(reqBody))
		srv.ServeHTTP(w, r)

		var resp v1.ActionResponse
		if w.Code == http.StatusOK {
			Expect(json.NewDecoder(w.Body).Decode(&resp)).To(Succeed())
		} else {
			err = json.NewDecoder(w.Body).Decode(&resp)
		}

		return resp, w.Code, err
	}

	BeforeEach(func() {
		rec = record.NewFakeRecorder(100)

		nodePool = "test-pool"
		testJobSetName = "test-jobset"

		// Create test JobSet
		jobset := &jobsetv1a.JobSet{
			ObjectMeta: metav1.ObjectMeta{
				Name:      testJobSetName,
				Namespace: testNamespace,
			},
			Spec: jobsetv1a.JobSetSpec{
				FailurePolicy: &jobsetv1a.FailurePolicy{
					MaxRestarts: 99,
				},
				ReplicatedJobs: []jobsetv1a.ReplicatedJob{
					{
						Name:     "rs-a",
						Replicas: 1,
						Template: batchv1.JobTemplateSpec{
							Spec: batchv1.JobSpec{
								Template: corev1.PodTemplateSpec{
									Spec: corev1.PodSpec{
										Containers: []corev1.Container{
											{
												Name:  "main",
												Image: "ubuntu",
												Command: []string{
													"bash",
													"-c",
													"sleep 6000",
												},
											},
										},
									},
								},
							},
						},
					},
				},
			},
		}
		Expect(k8sClient.Create(ctx, jobset)).To(Succeed())

		// Create test nodes
		// 2x2x2 TPU topology = 2 Nodes in a NodePool
		for i := 0; i < 2; i++ {
			node := &corev1.Node{
				ObjectMeta: metav1.ObjectMeta{
					Name: "node-" + string(uuid.NewUUID())[0:8],
					Labels: map[string]string{
						"cloud.google.com/gke-nodepool":          nodePool,
						"cloud.google.com/gke-accelerator-count": "4",
						"cloud.google.com/gke-tpu-topology":      "2x2x2",
					},
				},
				Spec: corev1.NodeSpec{
					ProviderID: "gce://test-project/test-zone/test-instance-" + string(uuid.NewUUID())[0:8],
				},
			}
			Expect(k8sClient.Create(ctx, node)).To(Succeed())
		}

		// Create test pod for JobSet leader
		pod := &corev1.Pod{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "leader-pod",
				Namespace: testNamespace,
				Labels: map[string]string{
					"jobset.sigs.k8s.io/jobset-name":           testJobSetName,
					"batch.kubernetes.io/job-completion-index": "0",
				},
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
		Expect(k8sClient.Create(ctx, pod)).To(Succeed())

		// Initialize server components
		gcpMock = &mockGCPInstanceManager{}
		actionTaker = actions.NewActionTaker(ctx, k8sClient, gcpMock, rec, actions.NewNoRateLimiter())
		srv = server.New(actionTaker)
	})

	AfterEach(func() {
		// Clean up all test nodes first
		var nodes corev1.NodeList
		err := k8sClient.List(ctx, &nodes)
		Expect(err).NotTo(HaveOccurred())
		for _, node := range nodes.Items {
			err = k8sClient.Delete(ctx, &node)
			Expect(err).NotTo(HaveOccurred())
		}

		// Delete the JobSet
		jobset := &jobsetv1a.JobSet{
			ObjectMeta: metav1.ObjectMeta{
				Name:      testJobSetName,
				Namespace: testNamespace,
			},
		}
		Expect(k8sClient.Delete(ctx, jobset)).To(Succeed())

		// Delete all the Pods
		pods := &corev1.PodList{}
		Expect(k8sClient.List(ctx, pods)).To(Succeed())
		for _, pod := range pods.Items {
			err = k8sClient.Delete(ctx, &pod)
			Expect(err).NotTo(HaveOccurred())
		}
	})

	Context("HTTP API", func() {
		It("should handle cordon node pool action", func() {
			req := v1.ActionRequest{
				ID:         string(uuid.NewUUID()),
				Requestor:  "integration-test",
				Type:       v1.ActionTypeCordonNodepool,
				NodePool:   nodePool,
				JobSetName: testJobSetName,
				Namespace:  testNamespace,
				PreflightChecks: v1.PreflightChecks{
					ExpectedNodeCounts: false,
				},
				Reason: "Integration test: cordon node pool",
			}

			resp, code, err := sendActionRequest(req)
			Expect(code).To(Equal(http.StatusOK))
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.ID).To(Equal(req.ID))
			Expect(resp.Error).To(BeEmpty())

			// Verify nodes are cordoned
			var nodes corev1.NodeList
			Expect(k8sClient.List(ctx, &nodes)).To(Succeed())
			for _, node := range nodes.Items {
				Expect(node.Spec.Unschedulable).To(BeTrue())
			}

			// Verify event was recorded
			events := rec.(*record.FakeRecorder).Events
			Expect(events).To(HaveLen(1))
			event := <-events
			Expect(event).To(ContainSubstring("Normal"))
			Expect(event).To(ContainSubstring(actions.EventReasonFailoverActionTriggered))
			Expect(event).To(ContainSubstring("Failover action triggered: cordon_nodepool"))
		})

		It("should handle cordon and restart jobset action", func() {
			req := v1.ActionRequest{
				ID:         string(uuid.NewUUID()),
				Requestor:  "integration-test",
				Type:       v1.ActionTypeCordonNodepoolAndRestartJobSet,
				NodePool:   nodePool,
				JobSetName: testJobSetName,
				Namespace:  testNamespace,
				Reason:     "Integration test: cordon and restart jobset",
			}

			resp, code, err := sendActionRequest(req)
			Expect(code).To(Equal(http.StatusOK))
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.ID).To(Equal(req.ID))
			Expect(resp.Error).To(BeEmpty())

			// Verify nodes are cordoned
			var nodes corev1.NodeList
			Expect(k8sClient.List(ctx, &nodes)).To(Succeed())
			for _, node := range nodes.Items {
				Expect(node.Spec.Unschedulable).To(BeTrue())
			}

			// Verify leader pod is deleted
			var pods corev1.PodList
			Expect(k8sClient.List(ctx, &pods, client.InNamespace(testNamespace))).To(Succeed())
			Expect(pods.Items).To(BeEmpty())

			// Verify event was recorded
			events := rec.(*record.FakeRecorder).Events
			Expect(events).To(HaveLen(1))
			event := <-events
			Expect(event).To(ContainSubstring("Normal"))
			Expect(event).To(ContainSubstring(actions.EventReasonFailoverActionTriggered))
			Expect(event).To(ContainSubstring("Failover action triggered: cordon_nodepool_and_restart_jobset"))
		})

		It("should handle cordon and repair node pool action", func() {
			req := v1.ActionRequest{
				ID:         string(uuid.NewUUID()),
				Requestor:  "integration-test",
				Type:       v1.ActionTypeCordonAndRepairNodepool,
				NodePool:   nodePool,
				JobSetName: testJobSetName,
				Reason:     "Integration test: cordon and repair node pool",
			}

			resp, code, err := sendActionRequest(req)
			Expect(code).To(Equal(http.StatusOK))
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.ID).To(Equal(req.ID))
			Expect(resp.Error).To(BeEmpty())

			// Verify nodes are cordoned
			var nodes corev1.NodeList
			Expect(k8sClient.List(ctx, &nodes)).To(Succeed())
			for _, node := range nodes.Items {
				Expect(node.Spec.Unschedulable).To(BeTrue())
			}

			// Verify a GCP instance was deleted
			Expect(gcpMock.deletedInstances).To(HaveLen(1))
			Expect(gcpMock.deletedInstances[0].name).To(HavePrefix("test-instance-"))
			Expect(gcpMock.deletedInstances[0].zone).To(Equal("test-zone"))
			Expect(gcpMock.deletedInstances[0].project).To(Equal("test-project"))

			// Verify event was recorded
			events := rec.(*record.FakeRecorder).Events
			Expect(events).To(HaveLen(1))
			event := <-events
			Expect(event).To(ContainSubstring("Normal"))
			Expect(event).To(ContainSubstring(actions.EventReasonFailoverActionTriggered))
			Expect(event).To(ContainSubstring("Failover action triggered: cordon_and_repair_nodepool"))
		})

		It("should handle repair node pool action", func() {
			req := v1.ActionRequest{
				ID:         string(uuid.NewUUID()),
				Requestor:  "integration-test",
				Type:       v1.ActionTypeRepairNodepool,
				NodePool:   nodePool,
				JobSetName: testJobSetName,
				Namespace:  testNamespace,
				PreflightChecks: v1.PreflightChecks{
					ExpectedNodeCounts: false,
				},
				Reason: "Integration test: repair node pool",
			}

			resp, code, err := sendActionRequest(req)
			Expect(code).To(Equal(http.StatusOK))
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.ID).To(Equal(req.ID))
			Expect(resp.Error).To(BeEmpty())

			// Verify nodes are NOT cordoned (this is the key difference from cordon_and_repair)
			var nodes corev1.NodeList
			Expect(k8sClient.List(ctx, &nodes)).To(Succeed())
			for _, node := range nodes.Items {
				Expect(node.Spec.Unschedulable).To(BeFalse())
			}

			// Verify a GCP instance was deleted
			Expect(gcpMock.deletedInstances).To(HaveLen(1))
			Expect(gcpMock.deletedInstances[0].name).To(HavePrefix("test-instance-"))
			Expect(gcpMock.deletedInstances[0].zone).To(Equal("test-zone"))
			Expect(gcpMock.deletedInstances[0].project).To(Equal("test-project"))

			// Verify event was recorded
			events := rec.(*record.FakeRecorder).Events
			Expect(events).To(HaveLen(1))
			event := <-events
			Expect(event).To(ContainSubstring("Normal"))
			Expect(event).To(ContainSubstring(actions.EventReasonFailoverActionTriggered))
			Expect(event).To(ContainSubstring("Failover action triggered: repair_nodepool"))
		})

		It("should handle repair node pool action with dry run", func() {
			req := v1.ActionRequest{
				ID:         string(uuid.NewUUID()),
				Requestor:  "integration-test",
				Type:       v1.ActionTypeRepairNodepool,
				NodePool:   nodePool,
				JobSetName: testJobSetName,
				Namespace:  testNamespace,
				PreflightChecks: v1.PreflightChecks{
					ExpectedNodeCounts: false,
				},
				DryRun: true,
				Reason: "Integration test: repair node pool (dry run)",
			}

			resp, code, err := sendActionRequest(req)
			Expect(code).To(Equal(http.StatusOK))
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.ID).To(Equal(req.ID))
			Expect(resp.Error).To(BeEmpty())

			// Verify nodes are NOT cordoned
			var nodes corev1.NodeList
			Expect(k8sClient.List(ctx, &nodes)).To(Succeed())
			for _, node := range nodes.Items {
				Expect(node.Spec.Unschedulable).To(BeFalse())
			}

			// Verify NO GCP instance was deleted (dry run)
			Expect(gcpMock.deletedInstances).To(BeEmpty())

			// Verify event was recorded
			events := rec.(*record.FakeRecorder).Events
			Expect(events).To(HaveLen(1))
			event := <-events
			Expect(event).To(ContainSubstring("Normal"))
			Expect(event).To(ContainSubstring(actions.EventReasonFailoverActionTriggered))
			Expect(event).To(ContainSubstring("Failover action triggered: repair_nodepool"))
			Expect(event).To(ContainSubstring("(dry run)"))
		})

		It("should handle invalid requests", func() {
			// Test with invalid action type
			req := v1.ActionRequest{
				ID:         string(uuid.NewUUID()),
				Requestor:  "integration-test",
				Type:       "invalid-action",
				NodePool:   nodePool,
				JobSetName: testJobSetName,
				Reason:     "Integration test: invalid action type",
			}

			resp, code, err := sendActionRequest(req)
			Expect(code).To(Equal(http.StatusBadRequest))
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.ID).To(Equal(req.ID))
			Expect(resp.Error).NotTo(BeEmpty())
		})

		It("should handle rate limited actions", func() {
			rateLimiter := actions.NewInMemoryRateLimiter(map[v1.ActionType]time.Duration{
				v1.ActionTypeCordonNodepool: 1 * time.Second,
			})

			// Update the action taker with the rate limiter
			actionTaker = actions.NewActionTaker(ctx, k8sClient, gcpMock, rec, rateLimiter)
			srv = server.New(actionTaker)

			// First request should succeed
			req := v1.ActionRequest{
				ID:         string(uuid.NewUUID()),
				Requestor:  "integration-test",
				Type:       v1.ActionTypeCordonNodepool,
				NodePool:   nodePool,
				JobSetName: testJobSetName,
				Namespace:  testNamespace,
				PreflightChecks: v1.PreflightChecks{
					ExpectedNodeCounts: false,
				},
				Reason: "Integration test: rate limiting",
			}

			resp, code, err := sendActionRequest(req)
			Expect(code).To(Equal(http.StatusOK))
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.ID).To(Equal(req.ID))
			Expect(resp.Error).To(BeEmpty())

			// Second request should be rate limited
			resp, code, err = sendActionRequest(req)
			Expect(code).To(Equal(http.StatusTooManyRequests))
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.ID).To(Equal(req.ID))
			Expect(resp.Error).To(Equal("action is currently rate limited"))

			// Wait for the rate limit to expire
			time.Sleep(1*time.Second + 100*time.Millisecond)

			// Third request should succeed after waiting
			resp, code, err = sendActionRequest(req)
			Expect(code).To(Equal(http.StatusOK))
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.ID).To(Equal(req.ID))
			Expect(resp.Error).To(BeEmpty())
		})
	})
})
