/*
Copyright 2025.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package integration

import (
	"context"
	"time"

	"github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/internal/controller"
	"github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/internal/historydb"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
)

var _ = Describe("Pod Controller", func() {
	var reconciler *controller.PodReconciler
	var historyDB *historydb.PostgresDB
	var jobUID string
	var ctx context.Context

	BeforeEach(func() {
		// Connect to the database
		var err error
		historyDB, err = historydb.NewDB("localhost", "5432", "postgres", "pass", "postgres")
		Expect(err).NotTo(HaveOccurred())

		// Create a unique job UID for this test
		jobUID = "test-job-" + time.Now().Format("20060102150405")

		// Set up the reconciler
		reconciler = &controller.PodReconciler{
			Client:    k8sClient,
			Scheme:    k8sClient.Scheme(),
			HistoryDB: historyDB,
		}

		// Set up context
		ctx = context.Background()
	})

	AfterEach(func() {
		// Clean up all pods created during tests
		podList := &corev1.PodList{}
		Expect(k8sClient.List(ctx, podList, client.InNamespace("default"))).To(Succeed())
		for _, pod := range podList.Items {
			Expect(k8sClient.Delete(ctx, &pod, client.GracePeriodSeconds(0))).To(Succeed())
		}

		// Clean up all nodes created during tests
		nodeList := &corev1.NodeList{}
		Expect(k8sClient.List(ctx, nodeList)).To(Succeed())
		for _, node := range nodeList.Items {
			Expect(k8sClient.Delete(ctx, &node, client.GracePeriodSeconds(0))).To(Succeed())
		}

		// Clean up test data in the database
		cleanupQuery := "DELETE FROM replicated_job_status WHERE job_uid = $1"
		_, err := historyDB.DB().Exec(cleanupQuery, jobUID)
		Expect(err).NotTo(HaveOccurred())

		// Close the database connection
		err = historyDB.Close()
		Expect(err).NotTo(HaveOccurred())
	})

	Context("When reconciling a Pod with valid labels", func() {
		const (
			podName    = "test-pod"
			jobName    = "test-job"
			jobSetName = "test-jobset"
			nodeName   = "test-node"
			nodePool   = "test-pool"
		)

		typeNamespacedName := types.NamespacedName{
			Name:      podName,
			Namespace: "default",
		}

		It("should save job status record for a pending pod", func() {
			By("Creating a pending pod with valid labels")
			pod := buildPod(podName, jobName, jobSetName, jobUID, "")
			Expect(k8sClient.Create(ctx, pod)).To(Succeed())

			By("Reconciling the pod")
			_, err := reconciler.Reconcile(ctx, reconcile.Request{
				NamespacedName: typeNamespacedName,
			})
			Expect(err).NotTo(HaveOccurred())

			By("Verifying job status record was saved")
			Eventually(func() error {
				record, err := historyDB.GetLastJobStatus(jobUID)
				if err != nil {
					return err
				}
				if record == nil {
					return nil
				}
				if record.Status != historydb.JobStatusPending {
					return nil
				}
				return nil
			}).Should(Succeed())

			record, err := historyDB.GetLastJobStatus(jobUID)
			Expect(err).NotTo(HaveOccurred())
			Expect(record).NotTo(BeNil())
			Expect(record.JobUID).To(Equal(jobUID))
			Expect(record.JobName).To(Equal(jobName))
			Expect(record.JobSetName).To(Equal(jobSetName))
			Expect(record.Status).To(Equal(historydb.JobStatusPending))
		})

		It("should save job status record for a scheduled pod", func() {
			By("Creating a node with node pool label")
			node := &corev1.Node{
				ObjectMeta: metav1.ObjectMeta{
					Name: nodeName,
					Labels: map[string]string{
						"cloud.google.com/gke-nodepool": nodePool,
					},
				},
			}
			Expect(k8sClient.Create(ctx, node)).To(Succeed())

			By("Creating a scheduled pod with valid labels")
			pod := buildPod(podName, jobName, jobSetName, jobUID, nodeName)
			Expect(k8sClient.Create(ctx, pod)).To(Succeed())

			By("Reconciling the pod")
			_, err := reconciler.Reconcile(ctx, reconcile.Request{
				NamespacedName: typeNamespacedName,
			})
			Expect(err).NotTo(HaveOccurred())

			var record *historydb.JobStatusRecord
			By("Verifying job status record was saved")
			Eventually(func() error {
				var err error
				record, err = historyDB.GetLastJobStatus(jobUID)
				if err != nil {
					return err
				}
				if record == nil {
					return nil
				}
				if record.Status != historydb.JobStatusScheduled {
					return nil
				}
				return nil
			}).Should(Succeed())

			Expect(record).NotTo(BeNil())
			Expect(record.JobUID).To(Equal(jobUID))
			Expect(record.JobName).To(Equal(jobName))
			Expect(record.JobSetName).To(Equal(jobSetName))
			Expect(record.Status).To(Equal(historydb.JobStatusScheduled))
			Expect(record.NodePool).To(Equal(nodePool))
		})

		It("should save job status record for an unschedulable pod", func() {
			By("Creating an unschedulable pod with valid labels")
			unschedulablePodName := "test-pod-unschedulable"
			pod := buildPod(unschedulablePodName, jobName, jobSetName, jobUID, "")
			Expect(k8sClient.Create(ctx, pod)).To(Succeed())
			pod.Status.Conditions = []corev1.PodCondition{
				{
					Type:   corev1.PodScheduled,
					Status: corev1.ConditionFalse,
					Reason: corev1.PodReasonUnschedulable,
				},
			}
			Expect(k8sClient.Status().Update(ctx, pod)).To(Succeed())

			By("Reconciling the pod")
			_, err := reconciler.Reconcile(ctx, reconcile.Request{
				NamespacedName: types.NamespacedName{
					Name:      unschedulablePodName,
					Namespace: "default",
				},
			})
			Expect(err).NotTo(HaveOccurred())

			By("Verifying job status record was saved")
			var record *historydb.JobStatusRecord
			Eventually(func() error {
				var err error
				record, err = historyDB.GetLastJobStatus(jobUID)
				if err != nil {
					return err
				}
				if record == nil {
					return nil
				}
				if record.Status != historydb.JobStatusUnschedulable {
					return nil
				}
				return nil
			}).Should(Succeed())

			Expect(record).NotTo(BeNil())
			Expect(record.JobUID).To(Equal(jobUID))
			Expect(record.JobName).To(Equal(jobName))
			Expect(record.JobSetName).To(Equal(jobSetName))
			Expect(record.Status).To(Equal(historydb.JobStatusUnschedulable))
		})
	})

	Context("When reconciling a Pod with missing labels", func() {
		const podName = "test-pod-missing-labels"

		typeNamespacedName := types.NamespacedName{
			Name:      podName,
			Namespace: "default",
		}

		It("should not save job status record", func() {
			By("Creating a pod with missing labels")
			pod := &corev1.Pod{
				ObjectMeta: metav1.ObjectMeta{
					Name:      podName,
					Namespace: "default",
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  "main",
							Image: "ubuntu",
						},
					},
				},
			}
			Expect(k8sClient.Create(ctx, pod)).To(Succeed())

			By("Reconciling the pod")
			_, err := reconciler.Reconcile(ctx, reconcile.Request{
				NamespacedName: typeNamespacedName,
			})
			Expect(err).NotTo(HaveOccurred())

			By("Verifying no job status record was saved")
			record, err := historyDB.GetLastJobStatus(jobUID)
			Expect(err).NotTo(HaveOccurred())
			Expect(record).To(BeNil())
		})
	})
})

func buildPod(podName, jobName, jobSetName, jobUID, nodeName string) *corev1.Pod {
	return &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      podName,
			Namespace: "default",
			Labels: map[string]string{
				controller.PodLabelJobName:    jobName,
				controller.PodLabelJobSetName: jobSetName,
			},
			OwnerReferences: []metav1.OwnerReference{
				{
					APIVersion: "batch/v1",
					Kind:       "Job",
					Name:       jobName,
					UID:        types.UID(jobUID),
					Controller: boolPtr(true),
				},
			},
		},
		Spec: corev1.PodSpec{
			NodeName: nodeName,
			Containers: []corev1.Container{
				{
					Name:  "main",
					Image: "ubuntu",
				},
			},
		},
	}
}

func boolPtr(b bool) *bool {
	return &b
}
