package main

import (
	"testing"

	rayv1 "github.com/ray-project/kuberay/ray-operator/apis/ray/v1"
	"github.com/ray-project/kuberay/ray-operator/controllers/ray/utils"
	admissionv1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/apimachinery/pkg/runtime"

	"github.com/stretchr/testify/assert"
)

var (
	namespaceStr                  string
	instanceName                  string
	groupNameStr                  string
	headGroupNameStr              string
	testPodAdmissionReviews       *admissionv1.AdmissionReview
	testCPUWorker                 *corev1.Pod
	testTPUWorker                 *corev1.Pod
	testRayClusterAdmissionReview *admissionv1.AdmissionReview
	testRayClusterNoTPUs          *rayv1.RayCluster
	testRayClusterSingleHostTPU   *rayv1.RayCluster
	testRayClusterMultiHostTPU    *rayv1.RayCluster
	testServices                  []runtime.Object
	workerSelector                labels.Selector
	headNodeIP                    string
)

func setupTest(t *testing.T) {
	namespaceStr = "test"
	instanceName = "raycluster-test-sample"
	headNodeIP = "1.2.3.4"
	groupNameStr = "test-group-name"
	headlessServiceSuffix = "headless-worker-svc"

	// CPU pod - doesn't request TPUs
	testCPUWorker = &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "cpu-pod",
			Namespace: namespaceStr,
			Labels: map[string]string{
				utils.RayNodeLabelKey:      "yes",
				utils.RayClusterLabelKey:   instanceName,
				utils.RayNodeGroupLabelKey: groupNameStr,
			},
		},
		Spec: corev1.PodSpec{
			Containers: []corev1.Container{
				{
					Name: "ray-worker",
				},
			},
		},
		Status: corev1.PodStatus{
			Phase: corev1.PodRunning,
			ContainerStatuses: []corev1.ContainerStatus{
				{
					Name:  "ray-worker",
					State: corev1.ContainerState{},
				},
			},
		},
	}

	// TPU Ray worker pod
	testTPUWorker = &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "tpu-pod",
			Namespace: namespaceStr,
			Labels: map[string]string{
				utils.RayNodeLabelKey:      "yes",
				utils.RayClusterLabelKey:   instanceName,
				utils.RayNodeGroupLabelKey: groupNameStr,
			},
		},
		Spec: corev1.PodSpec{
			Containers: []corev1.Container{
				{
					Name: "ray-worker",
					Resources: corev1.ResourceRequirements{
						Limits: corev1.ResourceList{
							"cpu":               resource.MustParse("1"),
							"google.com/tpu":    resource.MustParse("4"),
							"memory":            resource.MustParse("40G"),
							"ephemeral-storage": resource.MustParse("20Gi"),
						},
						Requests: corev1.ResourceList{
							"cpu":               resource.MustParse("1"),
							"google.com/tpu":    resource.MustParse("4"),
							"memory":            resource.MustParse("40G"),
							"ephemeral-storage": resource.MustParse("20Gi"),
						},
					},
				},
			},
		},
		Status: corev1.PodStatus{
			Phase: corev1.PodRunning,
			ContainerStatuses: []corev1.ContainerStatus{
				{
					Name:  "ray-worker",
					State: corev1.ContainerState{},
				},
			},
		},
	}
}

// helper function used by tests which mutate sliceToWorkers
func deepCopySliceToWorkers() map[slice][]worker {
	deepCopy := make(map[slice][]worker)
	for slice, workerList := range sliceToWorkers {
		deepCopy[slice] = []worker{}
		for _, worker := range workerList {
			deepCopy[slice] = append(deepCopy[slice], worker)
		}
	}

	return deepCopy
}

func Test_GetReplicaIndex(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		sliceToWorkers        map[slice][]worker
		numOfHosts            int32
		numReplicas           int
		additionalGroupStr    string
		additionalNumOfHosts  int32
		additionalNumReplicas int
		workersToDelete       []worker
	}{
		"single-host, single-slice worker group": {
			// single-slice, replicaIndex should always be 0
			numOfHosts:  1,
			numReplicas: 1,
		},
		"single-host, multi-slice worker group": {
			// multi-slice, replicaIndex should always be 0-numReplicas
			numOfHosts:  1,
			numReplicas: 4,
		},
		"multi-host, single-slice worker group": {
			// single-slice, replicaIndex should always be 0
			numOfHosts:  4,
			numReplicas: 1,
		},
		"multi-host, multi-slice worker group": {
			// multi-slice, replicaIndex should always be 0-numReplicas for 0-numOfHosts pods
			numOfHosts:  4,
			numReplicas: 4,
		},
		"multiple worker groups": {
			// should assign replicaIndex 0-numReplicas and TPU_WORKER_ID 0-numOfHosts
			// for each respective worker group
			numOfHosts:            4,
			numReplicas:           4,
			additionalGroupStr:    "another-worker-group",
			additionalNumOfHosts:  2,
			additionalNumReplicas: 3,
		},
		"deleted pods from replica": {
			// should re-assign pods to lowest index replicas with # isCreated pods < NumOfHosts
			numOfHosts:      4,
			numReplicas:     4,
			workersToDelete: []worker{worker{0, 0, true}, worker{2, 1, true}, worker{3, 2, true}},
		},
		"delete pods from different multi-host groups": {
			// pods should be reassigned the lowest replica ID with # isCreated pods < NumOfHosts
			// in each respective worker group
			numOfHosts:            4,
			numReplicas:           4,
			additionalGroupStr:    "another-worker-group",
			additionalNumOfHosts:  4,
			additionalNumReplicas: 3,
			workersToDelete:       []worker{worker{1, 0, true}, worker{2, 1, true}, worker{3, 2, true}},
		},
	}

	// validate getReplicaIndex() returns the expected Replica ID for TPU pods in varying pod slices
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			sliceToWorkersCopy := deepCopySliceToWorkers()
			for i := 0; i < tc.numReplicas; i++ {
				testPodSlice := slice{instanceName, groupNameStr, namespaceStr, i, tc.numOfHosts}
				for j := 0; j < int(tc.numOfHosts); j++ {
					replicaIndex := getReplicaIndex(instanceName, groupNameStr, namespaceStr)
					assert.Equal(t, i, replicaIndex)

					// add the worker to sliceToWorkers - this would happen in getNextWorkerID
					testWorker := worker{j, replicaIndex, true}
					if sliceToWorkers[testPodSlice] == nil {
						sliceToWorkers[testPodSlice] = []worker{testWorker}
					} else {
						sliceToWorkers[testPodSlice] = append(sliceToWorkers[testPodSlice], testWorker)
					}
				}
			}

			if len(tc.workersToDelete) > 0 {
				// test deleting and then re-assigning one pod at a time
				for _, workerToDelete := range tc.workersToDelete {
					// "delete" the pod
					replicaToDeleteFrom := workerToDelete.replicaIndex
					testPodSlice := slice{instanceName, groupNameStr, namespaceStr, replicaToDeleteFrom, tc.numOfHosts}
					// set the pod isCreated value to false to simulate pod deletion
					for index, worker := range sliceToWorkers[testPodSlice] {
						if worker.workerIndex == workerToDelete.workerIndex {
							sliceToWorkers[testPodSlice][index].isCreated = false
						}
					}

					// should re-assign the pod to the same replica
					replicaIndex := getReplicaIndex(instanceName, groupNameStr, namespaceStr)
					// set the pod isCreated value back to true to simulate pod re-creation
					for index, worker := range sliceToWorkers[testPodSlice] {
						if worker.workerIndex == workerToDelete.workerIndex {
							sliceToWorkers[testPodSlice][index].isCreated = true
						}
					}
					assert.Equal(t, replicaToDeleteFrom, replicaIndex)
				}

				// test deleting pods simultaneously and then re-assigning
				for _, workerToDelete := range tc.workersToDelete {
					testPodSlice := slice{instanceName, groupNameStr, namespaceStr, workerToDelete.replicaIndex, tc.numOfHosts}

					// set the pod isCreated value to false to simulate pod deletion
					for index, worker := range sliceToWorkers[testPodSlice] {
						if worker.workerIndex == workerToDelete.workerIndex {
							sliceToWorkers[testPodSlice][index].isCreated = false
						}
					}
				}
			}

			// test assigning pods to replicas for a different worker group
			if tc.additionalGroupStr != "" {
				for i := 0; i < tc.additionalNumReplicas; i++ {
					testAdditionalPodSlice := slice{instanceName, tc.additionalGroupStr, namespaceStr, i, tc.additionalNumOfHosts}
					for j := 0; j < int(tc.additionalNumOfHosts); j++ {
						replicaIndex := getReplicaIndex(instanceName, tc.additionalGroupStr, namespaceStr)
						assert.Equal(t, i, replicaIndex)

						// add the worker to sliceToWorkers - this would happen in getNextWorkerID
						testWorker := worker{j, replicaIndex, true}
						if sliceToWorkers[testAdditionalPodSlice] == nil {
							sliceToWorkers[testAdditionalPodSlice] = []worker{testWorker}
						} else {
							sliceToWorkers[testAdditionalPodSlice] = append(sliceToWorkers[testAdditionalPodSlice], testWorker)
						}
					}
				}

				// test deleting pods from a different worker group
				if len(tc.workersToDelete) > 0 {
					for _, workerToDelete := range tc.workersToDelete {
						replicaToDeleteFrom := workerToDelete.replicaIndex
						testAdditionalPodSlice := slice{instanceName, tc.additionalGroupStr, namespaceStr, replicaToDeleteFrom, tc.additionalNumOfHosts}
						for index, worker := range sliceToWorkers[testAdditionalPodSlice] {
							if worker.workerIndex == workerToDelete.workerIndex {
								sliceToWorkers[testAdditionalPodSlice][index].isCreated = false
							}
						}
					}
				}
			}

			// should re-assign the pod to the same replica for each respective worker group
			if len(tc.workersToDelete) > 0 {
				for _, workerToDelete := range tc.workersToDelete {
					testPodSlice := slice{instanceName, groupNameStr, namespaceStr, workerToDelete.replicaIndex, tc.numOfHosts}
					replicaIndex := getReplicaIndex(instanceName, groupNameStr, namespaceStr)
					// "re-create" the worker pod
					for index, worker := range sliceToWorkers[testPodSlice] {
						if worker.workerIndex == workerToDelete.workerIndex {
							sliceToWorkers[testPodSlice][index].isCreated = true
						}
					}
					assert.Equal(t, workerToDelete.replicaIndex, replicaIndex)

					if tc.additionalGroupStr != "" {
						testAdditionalPodSlice := slice{instanceName, tc.additionalGroupStr, namespaceStr, workerToDelete.replicaIndex, tc.additionalNumOfHosts}
						additionalReplicaIndex := getReplicaIndex(instanceName, tc.additionalGroupStr, namespaceStr)
						// "re-create" the worker pod
						for index, worker := range sliceToWorkers[testAdditionalPodSlice] {
							if worker.workerIndex == workerToDelete.workerIndex {
								sliceToWorkers[testAdditionalPodSlice][index].isCreated = true
							}
						}
						assert.Equal(t, workerToDelete.replicaIndex, additionalReplicaIndex)
					}
				}
			}

			assert.Equal(t, tc.numReplicas+tc.additionalNumReplicas, len(sliceToWorkers))
			sliceToWorkers = sliceToWorkersCopy // reset sliceToWorkers to previous state
		})
	}
}

func Test_GetNextWorkerID(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		numOfHosts            int32
		numReplicas           int
		workersToDelete       []worker
		additionalGroupStr    string
		additionalNumOfHosts  int32
		additionalNumReplicas int
	}{
		"single-host, single-slice worker group": {
			// single-host, TPU_WORKER_ID should always be 0
			numOfHosts:  1,
			numReplicas: 1,
		},
		"single-host, multi-slice worker group": {
			// multi-slice, TPU_WORKER_ID should be 0 for all replicas
			numOfHosts:  1,
			numReplicas: 4,
		},
		"multi-host, single-slice worker group": {
			// multi-host, TPU_WORKER_ID should range from 0 to NumOfHosts-1
			numOfHosts:  4,
			numReplicas: 1,
		},
		"multi-host, multi-slice worker group": {
			// multi-slice, unique TPU_WORKER_IDs should range from 0 to NumOfHosts-1 for each replica
			numOfHosts:  4,
			numReplicas: 4,
		},
		"delete pods from multi-host group": {
			// pods should be reassigned the lowest integer ID with isCreated == false belonging to the replica
			numOfHosts:      4,
			numReplicas:     4,
			workersToDelete: []worker{worker{0, 0, true}, worker{2, 1, true}, worker{3, 2, true}},
		},
		"delete pods from different multi-host groups": {
			// pods should be reassigned the lowest TPU_WORKER_ID ID with isCreated == false belonging to the replica
			// in each respective worker group
			numOfHosts:            4,
			numReplicas:           4,
			workersToDelete:       []worker{worker{0, 0, true}, worker{2, 1, true}, worker{3, 2, true}},
			additionalGroupStr:    "another-worker-group",
			additionalNumOfHosts:  4,
			additionalNumReplicas: 3,
		},
	}

	// validate getNextWorkerID() returns the expected TPU_WORKER ID for different worker group specifications
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			sliceToWorkersCopy := deepCopySliceToWorkers()
			for i := 0; i < tc.numReplicas; i++ {
				testPodSlice := slice{instanceName, groupNameStr, namespaceStr, i, tc.numOfHosts}
				for j := 0; j < int(tc.numOfHosts); j++ {
					workerID := getNextWorkerID(testPodSlice, namespaceStr, i)
					assert.Equal(t, j, workerID)
				}
			}

			if len(tc.workersToDelete) > 0 {
				// test deleting and then re-assigning one pod at a time
				for _, workerToDelete := range tc.workersToDelete {
					replicaToDeleteFrom := workerToDelete.replicaIndex
					testPodSlice := slice{instanceName, groupNameStr, namespaceStr, replicaToDeleteFrom, tc.numOfHosts}
					// set the pod isCreated value to false to simulate pod deletion
					for index, worker := range sliceToWorkers[testPodSlice] {
						if worker.workerIndex == workerToDelete.workerIndex {
							sliceToWorkers[testPodSlice][index].isCreated = false
						}
					}
					workerID := getNextWorkerID(testPodSlice, namespaceStr, replicaToDeleteFrom)
					assert.Equal(t, workerToDelete.workerIndex, workerID)
				}

				// test deleting pods simultaneously and then re-assigning
				for _, workerToDelete := range tc.workersToDelete {
					testPodSlice := slice{instanceName, groupNameStr, namespaceStr, workerToDelete.replicaIndex, tc.numOfHosts}
					// set the pod isCreated value to false to simulate pod deletion
					for index, worker := range sliceToWorkers[testPodSlice] {
						if worker.workerIndex == workerToDelete.workerIndex {
							sliceToWorkers[testPodSlice][index].isCreated = false
						}
					}
				}
			}

			// test assigning TPU_WORKER_IDs to pods for a different worker group
			if tc.additionalGroupStr != "" {
				for i := 0; i < tc.additionalNumReplicas; i++ {
					testAdditionalPodSlice := slice{instanceName, tc.additionalGroupStr, namespaceStr, i, tc.additionalNumOfHosts}
					for j := 0; j < int(tc.additionalNumOfHosts); j++ {
						workerID := getNextWorkerID(testAdditionalPodSlice, namespaceStr, i)
						assert.Equal(t, j, workerID)
					}
				}

				// test deleting pods from a different worker group
				if len(tc.workersToDelete) > 0 {
					for _, workerToDelete := range tc.workersToDelete {
						replicaToDeleteFrom := workerToDelete.replicaIndex
						testAdditionalPodSlice := slice{instanceName, tc.additionalGroupStr, namespaceStr, replicaToDeleteFrom, tc.additionalNumOfHosts}
						for index, worker := range sliceToWorkers[testAdditionalPodSlice] {
							if worker.workerIndex == workerToDelete.workerIndex {
								sliceToWorkers[testAdditionalPodSlice][index].isCreated = false
							}
						}
					}
				}
			}

			// should re-assign the pod to the same replica for each respective worker group
			if len(tc.workersToDelete) > 0 {
				for _, workerToDelete := range tc.workersToDelete {
					testPodSlice := slice{instanceName, groupNameStr, namespaceStr, workerToDelete.replicaIndex, tc.numOfHosts}
					workerID := getNextWorkerID(testPodSlice, namespaceStr, workerToDelete.replicaIndex)
					assert.Equal(t, workerToDelete.workerIndex, workerID)

					if tc.additionalGroupStr != "" {
						testAdditionalPodSlice := slice{instanceName, tc.additionalGroupStr, namespaceStr, workerToDelete.replicaIndex, tc.additionalNumOfHosts}
						additionalWorkerID := getNextWorkerID(testAdditionalPodSlice, namespaceStr, workerToDelete.replicaIndex)
						// "re-create" the worker pod
						for index, worker := range sliceToWorkers[testAdditionalPodSlice] {
							if worker.workerIndex == workerToDelete.workerIndex {
								sliceToWorkers[testAdditionalPodSlice][index].isCreated = true
							}
						}
						assert.Equal(t, workerToDelete.workerIndex, additionalWorkerID)
					}
				}
			}
			sliceToWorkers = sliceToWorkersCopy // reset sliceToWorkers to previous state
		})
	}
}
package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"testing"

	rayv1 "github.com/ray-project/kuberay/ray-operator/apis/ray/v1"
	"github.com/ray-project/kuberay/ray-operator/controllers/ray/utils"
	admissionv1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	// "k8s.io/apimachinery/pkg/labels"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/utils/pointer"

	"github.com/stretchr/testify/assert"
)

var (
	namespaceStr                  string
	instanceName                  string
	groupNameStr                  string
	headGroupNameStr              string
	testPodAdmissionReviews       *admissionv1.AdmissionReview
	testCPUPods                   []*corev1.Pod
	testTPUPods                   []*corev1.Pod
	testRayClusterAdmissionReview *admissionv1.AdmissionReview
	testRayClusterNoTPUs          *rayv1.RayCluster
	testRayClusterSingleHostTPU   *rayv1.RayCluster
	testRayClusterMultiHostTPU    *rayv1.RayCluster
	headNodeIP                    string
	testWorkerGroupSpec			  rayv1.WorkerGroupSpec
)

func setupTest(t *testing.T) {
	namespaceStr = "default"
	instanceName = "raycluster-sample"
	headNodeIP = "1.2.3.4"
	groupNameStr = "workergroup"
	headlessServiceSuffix = "headless-worker-svc"

	// 1 CPU head pod + 1 worker - doesn't request TPUs
	testCPUPods = []*corev1.Pod{
		&corev1.Pod{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "headNode",
				Namespace: namespaceStr,
				Labels: map[string]string{
					utils.RayNodeLabelKey:      "yes",
					utils.RayClusterLabelKey:   instanceName,
					utils.RayNodeTypeLabelKey:  string(rayv1.HeadNode),
					utils.RayNodeGroupLabelKey: headGroupNameStr,
				},
			},
			Spec: corev1.PodSpec{
				Containers: []corev1.Container{
					{
						Name:    "ray-head",
						Image:   "rayproject/autoscaler",
						Command: []string{"python"},
						Args:    []string{"/opt/code.py"},
					},
				},
			},
			Status: corev1.PodStatus{
				Phase: corev1.PodRunning,
				PodIP: headNodeIP,
				ContainerStatuses: []corev1.ContainerStatus{
					{
						Name:  "ray-head",
						State: corev1.ContainerState{},
					},
				},
			},
		},
		&corev1.Pod{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "pod1",
				Namespace: namespaceStr,
				Labels: map[string]string{
					utils.RayNodeLabelKey:      "yes",
					utils.RayClusterLabelKey:   instanceName,
					utils.RayNodeGroupLabelKey: groupNameStr,
				},
			},
			Spec: corev1.PodSpec{
				Containers: []corev1.Container{
					{
						Name: "ray-worker",
					},
				},
			},
			Status: corev1.PodStatus{
				Phase: corev1.PodRunning,
				ContainerStatuses: []corev1.ContainerStatus{
					{
						Name:  "ray-worker",
						State: corev1.ContainerState{},
					},
				},
			},
		},
	}

	// 1 CPU head pod + 4 TPU pods
	testTPUPods = []*corev1.Pod{
		&corev1.Pod{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "headNode",
				Namespace: namespaceStr,
				Labels: map[string]string{
					utils.RayNodeLabelKey:      "yes",
					utils.RayClusterLabelKey:   instanceName,
					utils.RayNodeTypeLabelKey:  string(rayv1.HeadNode),
					utils.RayNodeGroupLabelKey: headGroupNameStr,
				},
			},
			Spec: corev1.PodSpec{
				Containers: []corev1.Container{
					{
						Name: "ray-head",
					},
				},
			},
			Status: corev1.PodStatus{
				Phase: corev1.PodRunning,
				PodIP: headNodeIP,
				ContainerStatuses: []corev1.ContainerStatus{
					{
						Name:  "ray-head",
						State: corev1.ContainerState{},
					},
				},
			},
		},
		&corev1.Pod{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "pod1",
				Namespace: namespaceStr,
				Labels: map[string]string{
					utils.RayNodeLabelKey:      "yes",
					utils.RayClusterLabelKey:   instanceName,
					utils.RayNodeGroupLabelKey: groupNameStr,
				},
			},
			Spec: corev1.PodSpec{
				Containers: []corev1.Container{
					{
						Name: "ray-worker",
						Resources: corev1.ResourceRequirements{
							Limits: corev1.ResourceList{
								"cpu":               resource.MustParse("1"),
								"google.com/tpu":    resource.MustParse("4"),
								"memory":            resource.MustParse("40G"),
								"ephemeral-storage": resource.MustParse("20Gi"),
							},
							Requests: corev1.ResourceList{
								"cpu":               resource.MustParse("1"),
								"google.com/tpu":    resource.MustParse("4"),
								"memory":            resource.MustParse("40G"),
								"ephemeral-storage": resource.MustParse("20Gi"),
							},
						},
					},
				},
			},
			Status: corev1.PodStatus{
				Phase: corev1.PodRunning,
				ContainerStatuses: []corev1.ContainerStatus{
					{
						Name:  "ray-worker",
						State: corev1.ContainerState{},
					},
				},
			},
		},
		&corev1.Pod{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "pod2",
				Namespace: namespaceStr,
				Labels: map[string]string{
					utils.RayNodeLabelKey:      "yes",
					utils.RayClusterLabelKey:   instanceName,
					utils.RayNodeGroupLabelKey: groupNameStr,
				},
			},
			Spec: corev1.PodSpec{
				Containers: []corev1.Container{
					{
						Name: "ray-worker",
						Resources: corev1.ResourceRequirements{
							Limits: corev1.ResourceList{
								"cpu":               resource.MustParse("1"),
								"google.com/tpu":    resource.MustParse("4"),
								"memory":            resource.MustParse("40G"),
								"ephemeral-storage": resource.MustParse("20Gi"),
							},
							Requests: corev1.ResourceList{
								"cpu":               resource.MustParse("1"),
								"google.com/tpu":    resource.MustParse("4"),
								"memory":            resource.MustParse("40G"),
								"ephemeral-storage": resource.MustParse("20Gi"),
							},
						},
					},
				},
			},
			Status: corev1.PodStatus{
				Phase: corev1.PodRunning,
				ContainerStatuses: []corev1.ContainerStatus{
					{
						Name:  "ray-worker",
						State: corev1.ContainerState{},
					},
				},
			},
		},
		&corev1.Pod{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "pod3",
				Namespace: namespaceStr,
				Labels: map[string]string{
					utils.RayNodeLabelKey:      "yes",
					utils.RayClusterLabelKey:   instanceName,
					utils.RayNodeGroupLabelKey: groupNameStr,
				},
			},
			Spec: corev1.PodSpec{
				Containers: []corev1.Container{
					{
						Name: "ray-worker",
						Resources: corev1.ResourceRequirements{
							Limits: corev1.ResourceList{
								"cpu":               resource.MustParse("1"),
								"google.com/tpu":    resource.MustParse("4"),
								"memory":            resource.MustParse("40G"),
								"ephemeral-storage": resource.MustParse("20Gi"),
							},
							Requests: corev1.ResourceList{
								"cpu":               resource.MustParse("1"),
								"google.com/tpu":    resource.MustParse("4"),
								"memory":            resource.MustParse("40G"),
								"ephemeral-storage": resource.MustParse("20Gi"),
							},
						},
					},
				},
			},
			Status: corev1.PodStatus{
				Phase: corev1.PodRunning,
				ContainerStatuses: []corev1.ContainerStatus{
					{
						Name:  "ray-worker",
						State: corev1.ContainerState{},
					},
				},
			},
		},
		&corev1.Pod{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "pod4",
				Namespace: namespaceStr,
				Labels: map[string]string{
					utils.RayNodeLabelKey:      "yes",
					utils.RayClusterLabelKey:   instanceName,
					utils.RayNodeGroupLabelKey: groupNameStr,
				},
			},
			Spec: corev1.PodSpec{
				Containers: []corev1.Container{
					{
						Name: "ray-worker",
						Resources: corev1.ResourceRequirements{
							Limits: corev1.ResourceList{
								"cpu":               resource.MustParse("1"),
								"google.com/tpu":    resource.MustParse("4"),
								"memory":            resource.MustParse("40G"),
								"ephemeral-storage": resource.MustParse("20Gi"),
							},
							Requests: corev1.ResourceList{
								"cpu":               resource.MustParse("1"),
								"google.com/tpu":    resource.MustParse("4"),
								"memory":            resource.MustParse("40G"),
								"ephemeral-storage": resource.MustParse("20Gi"),
							},
						},
					},
				},
			},
			Status: corev1.PodStatus{
				Phase: corev1.PodRunning,
				ContainerStatuses: []corev1.ContainerStatus{
					{
						Name:  "ray-worker",
						State: corev1.ContainerState{},
					},
				},
			},
		},
	}

	// RayCluster requesting no TPU resources - pass-through
	testRayClusterNoTPUs = &rayv1.RayCluster{
		ObjectMeta: metav1.ObjectMeta{
			Name:      instanceName,
			Namespace: namespaceStr,
		},
		Spec: rayv1.RayClusterSpec{
			HeadGroupSpec: rayv1.HeadGroupSpec{
				Template: corev1.PodTemplateSpec{
					Spec: corev1.PodSpec{
						Containers: []corev1.Container{
							{
								Name: "ray-head",
							},
						},
					},
				},
			},
			WorkerGroupSpecs: []rayv1.WorkerGroupSpec{
				{
					Replicas:    pointer.Int32(1),
					MinReplicas: pointer.Int32(0),
					MaxReplicas: pointer.Int32(10000),
					NumOfHosts:  1,
					GroupName:   groupNameStr,
					Template: corev1.PodTemplateSpec{
						Spec: corev1.PodSpec{
							Containers: []corev1.Container{
								{
									Name: "ray-worker",
									Env: []corev1.EnvVar{
										{
											Name: "MY_POD_IP",
											ValueFrom: &corev1.EnvVarSource{
												FieldRef: &corev1.ObjectFieldSelector{
													FieldPath: "status.podIP",
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
		},
	}

	// RayCluster with 2x2x1 TPU topology worker group
	testRayClusterSingleHostTPU = &rayv1.RayCluster{
		ObjectMeta: metav1.ObjectMeta{
			Name:      instanceName,
			Namespace: namespaceStr,
		},
		Spec: rayv1.RayClusterSpec{
			HeadGroupSpec: rayv1.HeadGroupSpec{
				Template: corev1.PodTemplateSpec{
					Spec: corev1.PodSpec{
						Containers: []corev1.Container{
							{
								Name: "ray-head",
							},
						},
					},
				},
			},
			WorkerGroupSpecs: []rayv1.WorkerGroupSpec{
				{
					Replicas:    pointer.Int32(1),
					MinReplicas: pointer.Int32(0),
					MaxReplicas: pointer.Int32(10000),
					NumOfHosts:  1,
					GroupName:   groupNameStr,
					Template: corev1.PodTemplateSpec{
						Spec: corev1.PodSpec{
							Containers: []corev1.Container{
								{
									Name: "ray-worker",
									Env: []corev1.EnvVar{
										{
											Name: "MY_POD_IP",
											ValueFrom: &corev1.EnvVarSource{
												FieldRef: &corev1.ObjectFieldSelector{
													FieldPath: "status.podIP",
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
		},
	}

	// RayCluster with 2x2x4 TPU topology worker group
	testRayClusterMultiHostTPU = &rayv1.RayCluster{
		ObjectMeta: metav1.ObjectMeta{
			Name:      instanceName,
			Namespace: namespaceStr,
		},
		Spec: rayv1.RayClusterSpec{
			HeadGroupSpec: rayv1.HeadGroupSpec{
				Template: corev1.PodTemplateSpec{
					Spec: corev1.PodSpec{
						Containers: []corev1.Container{
							{
								Name: "ray-head",
							},
						},
					},
				},
			},
			WorkerGroupSpecs: []rayv1.WorkerGroupSpec{
				{
					Replicas:    pointer.Int32(1),
					MinReplicas: pointer.Int32(0),
					MaxReplicas: pointer.Int32(10000),
					NumOfHosts:  4,
					GroupName:   groupNameStr,
					Template: corev1.PodTemplateSpec{
						Spec: corev1.PodSpec{
							Containers: []corev1.Container{
								{
									Name: "ray-worker",
									Env: []corev1.EnvVar{
										{
											Name: "MY_POD_IP",
											ValueFrom: &corev1.EnvVarSource{
												FieldRef: &corev1.ObjectFieldSelector{
													FieldPath: "status.podIP",
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
		},
	}

	jsonBytes, _ := json.Marshal(testTPUPods[0])

	testPodAdmissionReviews = &admissionv1.AdmissionReview{
		Request: &admissionv1.AdmissionRequest{
			UID: "1",
			Kind: metav1.GroupVersionKind{
				Group:   "",
				Version: "v1",
				Kind:    "Pod",
			},
			Object: runtime.RawExtension{
				Raw:    jsonBytes,
				Object: testTPUPods[0],
			},
		},
	}

	testWorkerGroupSpec = rayv1.WorkerGroupSpec{
		Replicas:    pointer.Int32(1),
		MinReplicas: pointer.Int32(0),
		MaxReplicas: pointer.Int32(10000),
		NumOfHosts:  1,
		GroupName:   groupNameStr,
		Template: corev1.PodTemplateSpec{
			Spec: corev1.PodSpec{
				Containers: []corev1.Container{
					{
						Name: "ray-worker",
						Env: []corev1.EnvVar{
							{
								Name: "MY_POD_IP",
								ValueFrom: &corev1.EnvVarSource{
									FieldRef: &corev1.ObjectFieldSelector{
										FieldPath: "status.podIP",
									},
								},
							},
						},
					},
				},
			},
		},
	}
}

// helper function used by tests which mutate sliceToWorkers
func deepCopySliceToWorkers() map[slice][]worker {
	deepCopy := make(map[slice][]worker)
	for slice, workerList := range sliceToWorkers {
		deepCopy[slice] = []worker{}
		for _, worker := range workerList {
			deepCopy[slice] = append(deepCopy[slice], worker)
		}
	}

	return deepCopy
}

func Test_GetReplicaIndex(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		sliceToWorkers        map[slice][]worker
		numOfHosts            int32
		numReplicas           int
		additionalGroupStr    string
		additionalNumOfHosts  int32
		additionalNumReplicas int
		workersToDelete       []worker
	}{
		"single-host, single-slice worker group": {
			// single-slice, replicaIndex should always be 0
			numOfHosts:  1,
			numReplicas: 1,
		},
		"single-host, multi-slice worker group": {
			// multi-slice, replicaIndex should always be 0-numReplicas
			numOfHosts:  1,
			numReplicas: 4,
		},
		"multi-host, single-slice worker group": {
			// single-slice, replicaIndex should always be 0
			numOfHosts:  4,
			numReplicas: 1,
		},
		"multi-host, multi-slice worker group": {
			// multi-slice, replicaIndex should always be 0-numReplicas for 0-numOfHosts pods
			numOfHosts:  4,
			numReplicas: 4,
		},
		"multiple worker groups": {
			// should assign replicaIndex 0-numReplicas and TPU_WORKER_ID 0-numOfHosts
			// for each respective worker group
			numOfHosts:            4,
			numReplicas:           4,
			additionalGroupStr:    "another-worker-group",
			additionalNumOfHosts:  2,
			additionalNumReplicas: 3,
		},
		"deleted pods from replica": {
			// should re-assign pods to lowest index replicas with # isCreated pods < NumOfHosts
			numOfHosts:      4,
			numReplicas:     4,
			workersToDelete: []worker{worker{0, 0, true}, worker{2, 1, true}, worker{3, 2, true}},
		},
		"delete pods from different multi-host groups": {
			// pods should be reassigned the lowest replica ID with # isCreated pods < NumOfHosts
			// in each respective worker group
			numOfHosts:            4,
			numReplicas:           4,
			additionalGroupStr:    "another-worker-group",
			additionalNumOfHosts:  4,
			additionalNumReplicas: 3,
			workersToDelete:       []worker{worker{1, 0, true}, worker{2, 1, true}, worker{3, 2, true}},
		},
	}

	// validate getReplicaIndex() returns the expected Replica ID for TPU pods in varying pod slices
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			sliceToWorkersCopy := deepCopySliceToWorkers()
			for i := 0; i < tc.numReplicas; i++ {
				testPodSlice := slice{instanceName, groupNameStr, namespaceStr, i, tc.numOfHosts}
				for j := 0; j < int(tc.numOfHosts); j++ {
					replicaIndex := getReplicaIndex(instanceName, groupNameStr, namespaceStr)
					assert.Equal(t, i, replicaIndex)

					// add the worker to sliceToWorkers - this would happen in getNextWorkerID
					testWorker := worker{j, replicaIndex, true}
					if sliceToWorkers[testPodSlice] == nil {
						sliceToWorkers[testPodSlice] = []worker{testWorker}
					} else {
						sliceToWorkers[testPodSlice] = append(sliceToWorkers[testPodSlice], testWorker)
					}
				}
			}

			if len(tc.workersToDelete) > 0 {
				// test deleting and then re-assigning one pod at a time
				for _, workerToDelete := range tc.workersToDelete {
					// "delete" the pod
					replicaToDeleteFrom := workerToDelete.replicaIndex
					testPodSlice := slice{instanceName, groupNameStr, namespaceStr, replicaToDeleteFrom, tc.numOfHosts}
					// set the pod isCreated value to false to simulate pod deletion
					for index, worker := range sliceToWorkers[testPodSlice] {
						if worker.workerIndex == workerToDelete.workerIndex {
							sliceToWorkers[testPodSlice][index].isCreated = false
						}
					}

					// should re-assign the pod to the same replica
					replicaIndex := getReplicaIndex(instanceName, groupNameStr, namespaceStr)
					// set the pod isCreated value back to true to simulate pod re-creation
					for index, worker := range sliceToWorkers[testPodSlice] {
						if worker.workerIndex == workerToDelete.workerIndex {
							sliceToWorkers[testPodSlice][index].isCreated = true
						}
					}
					assert.Equal(t, replicaToDeleteFrom, replicaIndex)
				}

				// test deleting pods simultaneously and then re-assigning
				for _, workerToDelete := range tc.workersToDelete {
					testPodSlice := slice{instanceName, groupNameStr, namespaceStr, workerToDelete.replicaIndex, tc.numOfHosts}

					// set the pod isCreated value to false to simulate pod deletion
					for index, worker := range sliceToWorkers[testPodSlice] {
						if worker.workerIndex == workerToDelete.workerIndex {
							sliceToWorkers[testPodSlice][index].isCreated = false
						}
					}
				}
			}

			// test assigning pods to replicas for a different worker group
			if tc.additionalGroupStr != "" {
				for i := 0; i < tc.additionalNumReplicas; i++ {
					testAdditionalPodSlice := slice{instanceName, tc.additionalGroupStr, namespaceStr, i, tc.additionalNumOfHosts}
					for j := 0; j < int(tc.additionalNumOfHosts); j++ {
						replicaIndex := getReplicaIndex(instanceName, tc.additionalGroupStr, namespaceStr)
						assert.Equal(t, i, replicaIndex)

						// add the worker to sliceToWorkers - this would happen in getNextWorkerID
						testWorker := worker{j, replicaIndex, true}
						if sliceToWorkers[testAdditionalPodSlice] == nil {
							sliceToWorkers[testAdditionalPodSlice] = []worker{testWorker}
						} else {
							sliceToWorkers[testAdditionalPodSlice] = append(sliceToWorkers[testAdditionalPodSlice], testWorker)
						}
					}
				}

				// test deleting pods from a different worker group
				if len(tc.workersToDelete) > 0 {
					for _, workerToDelete := range tc.workersToDelete {
						replicaToDeleteFrom := workerToDelete.replicaIndex
						testAdditionalPodSlice := slice{instanceName, tc.additionalGroupStr, namespaceStr, replicaToDeleteFrom, tc.additionalNumOfHosts}
						for index, worker := range sliceToWorkers[testAdditionalPodSlice] {
							if worker.workerIndex == workerToDelete.workerIndex {
								sliceToWorkers[testAdditionalPodSlice][index].isCreated = false
							}
						}
					}
				}
			}

			// should re-assign the pod to the same replica for each respective worker group
			if len(tc.workersToDelete) > 0 {
				for _, workerToDelete := range tc.workersToDelete {
					testPodSlice := slice{instanceName, groupNameStr, namespaceStr, workerToDelete.replicaIndex, tc.numOfHosts}
					replicaIndex := getReplicaIndex(instanceName, groupNameStr, namespaceStr)
					// "re-create" the worker pod
					for index, worker := range sliceToWorkers[testPodSlice] {
						if worker.workerIndex == workerToDelete.workerIndex {
							sliceToWorkers[testPodSlice][index].isCreated = true
						}
					}
					assert.Equal(t, workerToDelete.replicaIndex, replicaIndex)

					if tc.additionalGroupStr != "" {
						testAdditionalPodSlice := slice{instanceName, tc.additionalGroupStr, namespaceStr, workerToDelete.replicaIndex, tc.additionalNumOfHosts}
						additionalReplicaIndex := getReplicaIndex(instanceName, tc.additionalGroupStr, namespaceStr)
						// "re-create" the worker pod
						for index, worker := range sliceToWorkers[testAdditionalPodSlice] {
							if worker.workerIndex == workerToDelete.workerIndex {
								sliceToWorkers[testAdditionalPodSlice][index].isCreated = true
							}
						}
						assert.Equal(t, workerToDelete.replicaIndex, additionalReplicaIndex)
					}
				}
			}

			assert.Equal(t, tc.numReplicas+tc.additionalNumReplicas, len(sliceToWorkers))
			sliceToWorkers = sliceToWorkersCopy // reset sliceToWorkers to previous state
		})
	}
}

func Test_GetNextWorkerID(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		numOfHosts            int32
		numReplicas           int
		workersToDelete       []worker
		additionalGroupStr    string
		additionalNumOfHosts  int32
		additionalNumReplicas int
	}{
		"single-host, single-slice worker group": {
			// single-host, TPU_WORKER_ID should always be 0
			numOfHosts:  1,
			numReplicas: 1,
		},
		"single-host, multi-slice worker group": {
			// multi-slice, TPU_WORKER_ID should be 0 for all replicas
			numOfHosts:  1,
			numReplicas: 4,
		},
		"multi-host, single-slice worker group": {
			// multi-host, TPU_WORKER_ID should range from 0 to NumOfHosts-1
			numOfHosts:  4,
			numReplicas: 1,
		},
		"multi-host, multi-slice worker group": {
			// multi-slice, unique TPU_WORKER_IDs should range from 0 to NumOfHosts-1 for each replica
			numOfHosts:  4,
			numReplicas: 4,
		},
		"delete pods from multi-host group": {
			// pods should be reassigned the lowest integer ID with isCreated == false belonging to the replica
			numOfHosts:      4,
			numReplicas:     4,
			workersToDelete: []worker{worker{0, 0, true}, worker{2, 1, true}, worker{3, 2, true}},
		},
		"delete pods from different multi-host groups": {
			// pods should be reassigned the lowest TPU_WORKER_ID ID with isCreated == false belonging to the replica
			// in each respective worker group
			numOfHosts:            4,
			numReplicas:           4,
			workersToDelete:       []worker{worker{0, 0, true}, worker{2, 1, true}, worker{3, 2, true}},
			additionalGroupStr:    "another-worker-group",
			additionalNumOfHosts:  4,
			additionalNumReplicas: 3,
		},
	}

	// validate getNextWorkerID() returns the expected TPU_WORKER ID for different worker group specifications
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			sliceToWorkersCopy := deepCopySliceToWorkers()
			for i := 0; i < tc.numReplicas; i++ {
				testPodSlice := slice{instanceName, groupNameStr, namespaceStr, i, tc.numOfHosts}
				for j := 0; j < int(tc.numOfHosts); j++ {
					workerID := getNextWorkerID(testPodSlice, namespaceStr, i)
					assert.Equal(t, j, workerID)
				}
			}

			if len(tc.workersToDelete) > 0 {
				// test deleting and then re-assigning one pod at a time
				for _, workerToDelete := range tc.workersToDelete {
					replicaToDeleteFrom := workerToDelete.replicaIndex
					testPodSlice := slice{instanceName, groupNameStr, namespaceStr, replicaToDeleteFrom, tc.numOfHosts}
					// set the pod isCreated value to false to simulate pod deletion
					for index, worker := range sliceToWorkers[testPodSlice] {
						if worker.workerIndex == workerToDelete.workerIndex {
							sliceToWorkers[testPodSlice][index].isCreated = false
						}
					}
					workerID := getNextWorkerID(testPodSlice, namespaceStr, replicaToDeleteFrom)
					assert.Equal(t, workerToDelete.workerIndex, workerID)
				}

				// test deleting pods simultaneously and then re-assigning
				for _, workerToDelete := range tc.workersToDelete {
					testPodSlice := slice{instanceName, groupNameStr, namespaceStr, workerToDelete.replicaIndex, tc.numOfHosts}
					// set the pod isCreated value to false to simulate pod deletion
					for index, worker := range sliceToWorkers[testPodSlice] {
						if worker.workerIndex == workerToDelete.workerIndex {
							sliceToWorkers[testPodSlice][index].isCreated = false
						}
					}
				}
			}

			// test assigning TPU_WORKER_IDs to pods for a different worker group
			if tc.additionalGroupStr != "" {
				for i := 0; i < tc.additionalNumReplicas; i++ {
					testAdditionalPodSlice := slice{instanceName, tc.additionalGroupStr, namespaceStr, i, tc.additionalNumOfHosts}
					for j := 0; j < int(tc.additionalNumOfHosts); j++ {
						workerID := getNextWorkerID(testAdditionalPodSlice, namespaceStr, i)
						assert.Equal(t, j, workerID)
					}
				}

				// test deleting pods from a different worker group
				if len(tc.workersToDelete) > 0 {
					for _, workerToDelete := range tc.workersToDelete {
						replicaToDeleteFrom := workerToDelete.replicaIndex
						testAdditionalPodSlice := slice{instanceName, tc.additionalGroupStr, namespaceStr, replicaToDeleteFrom, tc.additionalNumOfHosts}
						for index, worker := range sliceToWorkers[testAdditionalPodSlice] {
							if worker.workerIndex == workerToDelete.workerIndex {
								sliceToWorkers[testAdditionalPodSlice][index].isCreated = false
							}
						}
					}
				}
			}

			// should re-assign the pod to the same replica for each respective worker group
			if len(tc.workersToDelete) > 0 {
				for _, workerToDelete := range tc.workersToDelete {
					testPodSlice := slice{instanceName, groupNameStr, namespaceStr, workerToDelete.replicaIndex, tc.numOfHosts}
					workerID := getNextWorkerID(testPodSlice, namespaceStr, workerToDelete.replicaIndex)
					assert.Equal(t, workerToDelete.workerIndex, workerID)

					if tc.additionalGroupStr != "" {
						testAdditionalPodSlice := slice{instanceName, tc.additionalGroupStr, namespaceStr, workerToDelete.replicaIndex, tc.additionalNumOfHosts}
						additionalWorkerID := getNextWorkerID(testAdditionalPodSlice, namespaceStr, workerToDelete.replicaIndex)
						// "re-create" the worker pod
						for index, worker := range sliceToWorkers[testAdditionalPodSlice] {
							if worker.workerIndex == workerToDelete.workerIndex {
								sliceToWorkers[testAdditionalPodSlice][index].isCreated = true
							}
						}
						assert.Equal(t, workerToDelete.workerIndex, additionalWorkerID)
					}
				}
			}
			sliceToWorkers = sliceToWorkersCopy // reset sliceToWorkers to previous state
		})
	}
}

func Test_ContainerRequestingTPUs(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		testPods     []*corev1.Pod
		requestsTPUs bool
	}{
		"Check for containerRequestingTPUs in CPU pods": {
			// no TPUs requested - should all be false
			testPods:     testCPUPods,
			requestsTPUs: false,
		},
		"Check for containerRequestingTPUs in TPU pods": {
			// TPUs requested - should all be true for worker pod containers
			testPods:     testTPUPods,
			requestsTPUs: true,
		},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			for _, pod := range tc.testPods {
				if pod.Labels[utils.RayNodeTypeLabelKey] == string(rayv1.WorkerNode) {
					assert.Equal(t, tc.requestsTPUs, containerRequestingTPUs(pod.Spec.Containers...))
				}
			}
		})
	}
}

func Test_GetNumTPUHostsFromTopology(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		topology        string
		acceleratorType string
		expectedHosts   int32
		expectedError   error
	}{
		"getNumTPUHostsFromTopology with empty topology": {
			// empty gke-tpu-topology - returns error
			topology:        "",
			acceleratorType: "tpu-v4-podslice",
			expectedHosts:   int32(0),
			expectedError:   errors.New("TPU topology not specified"),
		},
		"getNumTPUHostsFromTopology with empty gke-tpu-accelerator": {
			// empty gke-tpu-accelerator - defaults to 4 chips per host
			topology:        "2x2x1",
			expectedHosts:   int32(1),
			acceleratorType: "",
		},
		"getNumTPUHostsFromTopology with v4 2x2x1 topology": {
			// v4 - 2x2x1, 4 chips per host, should return 1 TPU VM
			topology:        "2x2x1",
			expectedHosts:   int32(1),
			acceleratorType: "tpu-v4-podslice",
		},
		"getNumTPUHostsFromTopology with v4 2x2x4 topology": {
			// v4 - 2x2x4, 4 chips per host, should return 4 TPU VMs
			topology:        "2x2x4",
			expectedHosts:   int32(4),
			acceleratorType: "tpu-v4-podslice",
		},
		"getNumTPUHostsFromTopology with v5litepod-4 2x4 topology": {
			// v5e - 2x4 and 4 chips per VM, should return 2 TPU VMs
			topology:        "2x4",
			expectedHosts:   int32(2),
			acceleratorType: "v5litepod-4",
		},
		"getNumTPUHostsFromTopology with v5litepod-8 2x4 topology": {
			// v5e - 2x4 and 8 chips per VM, should return 1 TPU VM
			topology:        "2x4",
			expectedHosts:   int32(1),
			acceleratorType: "v5litepod-8",
		},
		"getNumTPUHostsFromTopology with v5litepod-16 4x4 topology": {
			// v5e - 4x4 and 4 chips per VM, should return 4 TPU VMs
			topology:        "4x4",
			expectedHosts:   int32(4),
			acceleratorType: "v5litepod-16",
		},
	}

	// validate that getNumTPUHostsFromTopology returns the expected # TPU VM Hosts for varying TPU podslice types
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			vms, err := getNumTPUHostsFromTopology(instanceName, groupNameStr, namespaceStr, tc.topology, tc.acceleratorType)
			if err == nil {
				assert.Equal(t, tc.expectedHosts, vms)
			}
			if tc.topology == "" {
				assert.Equal(t, tc.expectedError, err)
			}
		})
	}
}

func Test_IsTPUMultiHost(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		topology          string
		acceleratorType   string
		expectedMultiHost bool
		expectedError     error
	}{
		"isTPUMultiHost with empty topology": {
			// empty gke-tpu-topology - returns error
			topology:          "",
			acceleratorType:   "tpu-v4-podslice",
			expectedMultiHost: false,
			expectedError:     errors.New("TPU topology not specified"),
		},
		"isTPUMultiHost with empty gke-tpu-accelerator": {
			// empty gke-tpu-accelerator - defaults to 4 chips per host
			topology:          "2x2x1",
			acceleratorType:   "",
			expectedMultiHost: false,
		},
		"isTPUMultiHost with v4 2x2x1 topology": {
			// v4 - 2x2x1, 4 chips per host, single-host
			topology:          "2x2x1",
			acceleratorType:   "tpu-v4-podslice",
			expectedMultiHost: false,
		},
		"isTPUMultiHost with v4 2x2x4 topology": {
			// v4 - 2x2x4, 4 chips per host, multi-host
			topology:          "2x2x4",
			acceleratorType:   "tpu-v4-podslice",
			expectedMultiHost: true,
		},
		"isTPUMultiHost with v5litepod-4 2x4 topology": {
			// v5e - 2x4 and 4 chips per VM, multi-host
			topology:          "2x4",
			acceleratorType:   "v5litepod-4",
			expectedMultiHost: true,
		},
		"isTPUMultiHost with v5litepod-8 2x4 topology": {
			// v5e - 2x4 and 8 chips per VM, single-host
			topology:          "2x4",
			acceleratorType:   "v5litepod-8",
			expectedMultiHost: false,
		},
		"isTPUMultiHost with v5litepod-16 4x4 topology": {
			// v5e - 4x4 and 4 chips per VM, multi-host
			topology:          "4x4",
			acceleratorType:   "v5litepod-16",
			expectedMultiHost: true,
		},
	}

	// validate that isTPUMultiHost correctly returns whether a given topology/accelerator is multi-host
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			isMultiHost, err := isTPUMultiHost(instanceName, groupNameStr, namespaceStr, tc.topology, tc.acceleratorType)
			assert.Equal(t, tc.expectedMultiHost, isMultiHost)
			if tc.expectedError != nil {
				assert.Equal(t, tc.expectedError, err)
			}
		})
	}
}

// func Test_ExtractRayCluster(t *testing.T) {
// 	setupTest(t)

// 	tests := map[string]struct {
// 		testRayCluster *rayv1.RayCluster
// 	}{}

// 	// validate that extractRayCluster correctly unmarshals admission review object
// 	for name, tc := range tests {
// 		t.Run(name, func(t *testing.T) {

// 		})
// 	}
// }

func Test_GetDNSHostnames(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		workerGroupSpec   rayv1.WorkerGroupSpec
		replicaIndex      int
		numOfHosts        int32
		expectedHostnames string
		expectedError     error
	}{
		"genDNSHostnames with NumOfHosts == 0": {
			// you can't have a workergroup with NumOfHosts set to 0 so this should error out
			workerGroupSpec: testWorkerGroupSpec,
			replicaIndex:    0,
			numOfHosts:      int32(0),
			expectedError:   errors.New("workerGroupSpec NumOfHosts not set"),
		},
		"genDNSHostnames with NumOfHosts == 1": {
			// Single-host worker group, should return a single DNS hostname. This function will
			// never be called for single-host groups, but we don't necessarily want it to error if it does.
			workerGroupSpec:   testWorkerGroupSpec,
			replicaIndex:      0,
			numOfHosts:        int32(1),
			expectedHostnames: fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 0, 0, instanceName, headlessServiceSuffix),
		},
		"genDNSHostnames with NumOfHosts > 1": {
			// multi-host worker group, should return a string list of DNS hostnames for the given replica
			workerGroupSpec: testWorkerGroupSpec,
			replicaIndex:    1,
			numOfHosts:      int32(4),
			expectedHostnames: strings.Join([]string{fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 1, 0, instanceName, headlessServiceSuffix),
				fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 1, 1, instanceName, headlessServiceSuffix),
				fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 1, 2, instanceName, headlessServiceSuffix),
				fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 1, 3, instanceName, headlessServiceSuffix),
			}, ","),
		},
	}

	// validate that genDNSHostnames correctly returns a string list of DNS addressable hostnames
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			// save a copy of headlessServiceName so we can reset it after the test
			headlessServiceNameCopy := strings.Clone(headlessServiceName)
			headlessServiceName = instanceName + "-" + headlessServiceSuffix
			tc.workerGroupSpec.NumOfHosts = tc.numOfHosts
			hostnames, err := genDNSHostnames(tc.workerGroupSpec, instanceName, namespaceStr, tc.replicaIndex)
			if tc.numOfHosts == 0 {
				assert.Equal(t, tc.expectedError, err)
			} else {
				assert.Equal(t, tc.expectedHostnames, hostnames)
			}
			headlessServiceName = headlessServiceNameCopy
		})
	}
}

func Test_InjectHostnames(t *testing.T) {
	setupTest(t)

	// injectHostnames(hostNames string, envPath string, container corev1.Container, patches *[]patch)

}

func Test_InjectMultiHostReplicaLabel(t *testing.T) {
	setupTest(t)

}

func Test_InjectPodAffinity(t *testing.T) {
	setupTest(t)

}

func Test_CheckWorkersMatchTopology(t *testing.T) {
	setupTest(t)

}

func Test_ValidateRayCluster(t *testing.T) {
	setupTest(t)

}

func Test_GetEnvironmentVariable(t *testing.T) {
	setupTest(t)

}

func Test_ExtractPod(t *testing.T) {
	setupTest(t)

}

func Test_MutatePod(t *testing.T) {
	setupTest(t)

}

func Test_DeletePod(t *testing.T) {
	setupTest(t)

	// delete a pod -> isCreated should be set to false after
}
