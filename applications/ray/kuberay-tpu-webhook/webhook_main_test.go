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
