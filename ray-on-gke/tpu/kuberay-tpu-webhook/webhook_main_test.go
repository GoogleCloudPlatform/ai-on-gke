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
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/utils/pointer"

	"github.com/stretchr/testify/assert"
)

var (
	namespaceStr        string
	instanceName        string
	groupNameStr        string
	headGroupNameStr    string
	testCPUWorker       *corev1.Pod
	testTPUWorker       *corev1.Pod
	testCPUPods         []*corev1.Pod
	testTPUPods         []*corev1.Pod
	testAdmissionReview *admissionv1.AdmissionReview
	testRayCluster      *rayv1.RayCluster
	headNodeIP          string
	testWorkerGroupSpec *rayv1.WorkerGroupSpec
)

func setupTest(t *testing.T) {
	namespaceStr = "unit-tests"
	instanceName = "raycluster-test-sample"
	headNodeIP = "1.2.3.4"
	groupNameStr = "test-group-name"

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
			NodeSelector: map[string]string{},
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
							"google.com/tpu": resource.MustParse("4"),
						},
						Requests: corev1.ResourceList{
							"google.com/tpu": resource.MustParse("4"),
						},
					},
					Env: []corev1.EnvVar{},
				},
			},
			NodeSelector: map[string]string{},
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

	testWorkerGroupSpec = &rayv1.WorkerGroupSpec{
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
						Resources: corev1.ResourceRequirements{
							Limits: corev1.ResourceList{
								"google.com/tpu": resource.MustParse("4"),
							},
							Requests: corev1.ResourceList{
								"google.com/tpu": resource.MustParse("4"),
							},
						},
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
				NodeSelector: map[string]string{},
			},
		},
	}

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
	}
	// add CPU worker
	testCPUPods = append(testCPUPods, testCPUWorker)

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
	}

	// add the 4 TPU worker pods using the testTPUWorker template
	for i := 0; i < 4; i++ {
		testTPUWorkerCopy := testTPUWorker.DeepCopy()
		testTPUWorkerCopy.Name = fmt.Sprintf("%s-%d", "tpu-pod", i)
		testTPUPods = append(testTPUPods, testTPUWorkerCopy)
	}

	// RayCluster with 2x2x4 TPU topology worker group
	testRayCluster = &rayv1.RayCluster{
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
									Resources: corev1.ResourceRequirements{
										Requests: corev1.ResourceList{
											"cpu":            resource.MustParse("1"),
											"google.com/tpu": resource.MustParse("4"),
										},
										Limits: corev1.ResourceList{
											"cpu":            resource.MustParse("1"),
											"google.com/tpu": resource.MustParse("4"),
										},
									},
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
							NodeSelector: map[string]string{},
						},
					},
				},
			},
		},
	}

	testAdmissionReview = &admissionv1.AdmissionReview{
		Request: &admissionv1.AdmissionRequest{
			UID: "1",
			Kind: metav1.GroupVersionKind{
				Kind: "Pod",
			},
			Operation: "CREATE",
			// set these values inside test
			Object: runtime.RawExtension{
				Raw:    nil,
				Object: nil,
			},
			OldObject: runtime.RawExtension{
				Raw:    nil,
				Object: nil,
			},
		},
	}
}

// helper function used by tests which mutate sliceToHostnames
func deepCopySliceToHostnames() map[slice]string {
	deepCopy := make(map[slice]string)
	for slice, hostnames := range sliceToHostnames {
		deepCopy[slice] = hostnames
	}

	return deepCopy
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

	// check containerRequestingTPUs returns true when a container requests google.com/tpu resources
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
		topology      string
		chipsPerHost  int64
		expectedHosts int32
		expectedError error
	}{
		"getNumTPUHostsFromTopology with empty topology": {
			// empty gke-tpu-topology - returns error
			topology:      "",
			expectedHosts: int32(0),
			expectedError: errors.New("TPU topology not specified"),
		},
		"getNumTPUHostsFromTopology with v4 2x2x1 topology": {
			// v4 - 2x2x1, 4 chips per host, should return 1 TPU VM
			topology:      "2x2x1",
			expectedHosts: int32(1),
			chipsPerHost:  int64(4),
		},
		"getNumTPUHostsFromTopology with v4 2x2x4 topology": {
			// v4 - 2x2x4, 4 chips per host, should return 4 TPU VMs
			topology:      "2x2x4",
			expectedHosts: int32(4),
			chipsPerHost:  int64(4),
		},
		"getNumTPUHostsFromTopology with v5litepod-4 2x4 topology": {
			// v5e - 2x4 and 4 chips per VM, should return 2 TPU VMs
			topology:      "2x4",
			expectedHosts: int32(2),
			chipsPerHost:  int64(4),
		},
		"getNumTPUHostsFromTopology with v5litepod-8 2x4 topology": {
			// v5e - 2x4 and 8 chips per VM, should return 1 TPU VM
			topology:      "2x4",
			expectedHosts: int32(1),
			chipsPerHost:  int64(8),
		},
		"getNumTPUHostsFromTopology with v5litepod-16 4x4 topology": {
			// v5e - 4x4 and 4 chips per VM, should return 4 TPU VMs
			topology:      "4x4",
			expectedHosts: int32(4),
			chipsPerHost:  int64(4),
		},
	}

	// validate that getNumTPUHostsFromTopology returns the expected # TPU VM Hosts for varying TPU podslice types
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			vms, err := getNumTPUHostsFromTopology(instanceName, groupNameStr, namespaceStr, tc.topology, tc.chipsPerHost)
			if err == nil {
				assert.Equal(t, tc.expectedHosts, vms)
			}
			if tc.topology == "" {
				assert.Equal(t, tc.expectedError, err)
			}
		})
	}
}

func Test_GetNumTPUChipsRequested(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		testPod            *corev1.Pod
		expectedTPULimit   map[corev1.ResourceName]resource.Quantity
		expectedTPURequest map[corev1.ResourceName]resource.Quantity
		expectedNumChips   int64
	}{
		"getNumTPUChipsRequested no TPUs requested": {
			// doesn't request TPUs - returns 0
			testPod:            testCPUWorker.DeepCopy(),
			expectedTPULimit:   map[corev1.ResourceName]resource.Quantity{"google.com/tpu": resource.MustParse("0")},
			expectedTPURequest: map[corev1.ResourceName]resource.Quantity{"google.com/tpu": resource.MustParse("0")},
			expectedNumChips:   int64(0),
		},
		"getNumTPUChipsRequested only TPU limit resource set": {
			// includes TPU limits but omits request - defaults to limit value
			testPod:            testTPUWorker.DeepCopy(),
			expectedTPULimit:   map[corev1.ResourceName]resource.Quantity{"google.com/tpu": resource.MustParse("4")},
			expectedTPURequest: nil,
			expectedNumChips:   int64(4),
		},
		"getNumTPUChipsRequested with TPU Request > TPU Limit": {
			// TPU Limit = maximum number of TPU chips requested
			testPod:            testTPUWorker.DeepCopy(),
			expectedTPULimit:   map[corev1.ResourceName]resource.Quantity{"google.com/tpu": resource.MustParse("4")},
			expectedTPURequest: map[corev1.ResourceName]resource.Quantity{"google.com/tpu": resource.MustParse("8")},
			expectedNumChips:   int64(4),
		},
		"getNumTPUChipsRequested with v4 TPU request": {
			// v4 - always 4 chips per VM
			testPod:            testTPUWorker.DeepCopy(),
			expectedTPULimit:   map[corev1.ResourceName]resource.Quantity{"google.com/tpu": resource.MustParse("4")},
			expectedTPURequest: map[corev1.ResourceName]resource.Quantity{"google.com/tpu": resource.MustParse("4")},
			expectedNumChips:   int64(4),
		},
		"getNumTPUChipsRequested with v5e ct5lp-hightpu-1t TPU request": {
			// v5e - 1x1 and 1 chip per VM
			testPod:            testTPUWorker.DeepCopy(),
			expectedTPULimit:   map[corev1.ResourceName]resource.Quantity{"google.com/tpu": resource.MustParse("1")},
			expectedTPURequest: map[corev1.ResourceName]resource.Quantity{"google.com/tpu": resource.MustParse("1")},
			expectedNumChips:   int64(1),
		},
		"getNumTPUChipsRequested with v5e ct5lp-hightpu-8t TPU request": {
			// v5e - 2x4 and 8 chips per VM
			testPod:            testTPUWorker.DeepCopy(),
			expectedTPULimit:   map[corev1.ResourceName]resource.Quantity{"google.com/tpu": resource.MustParse("8")},
			expectedTPURequest: map[corev1.ResourceName]resource.Quantity{"google.com/tpu": resource.MustParse("8")},
			expectedNumChips:   int64(8),
		},
	}

	// validate that getNumTPUChipsRequested correctly returns the number of TPU chips requested per Pod container
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			container := tc.testPod.Spec.Containers[0]
			container.Resources.Limits = tc.expectedTPULimit
			container.Resources.Requests = tc.expectedTPURequest
			chipsPerHost := getNumTPUChipsRequested(container)
			assert.Equal(t, tc.expectedNumChips, chipsPerHost)
		})
	}
}

func Test_ExtractPod(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		testPod       *corev1.Pod
		expectedKind  string
		expectedError error
	}{
		"extractPod with wrong admissionRequest Kind": {
			// should return an error since Kind != Pod
			testPod:       testTPUWorker.DeepCopy(),
			expectedKind:  "RayCluster",
			expectedError: errors.New("Expected Pod but got RayCluster"),
		},
		"extractPod with admissionRequest Kind == Pod": {
			// should successfully unmarshal the Pod object
			testPod:      testTPUWorker.DeepCopy(),
			expectedKind: "Pod",
		},
	}

	// validate that extractPod correctly unmarshals admissionReview object
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			// set up admissionReview object
			admissionReview := testAdmissionReview.DeepCopy()
			jsonPod, _ := json.Marshal(tc.testPod)
			admissionReview.Request.Object.Raw = jsonPod
			admissionReview.Request.Object.Object = tc.testPod

			// set Request Kind
			admissionReview.Request.Kind.Kind = tc.expectedKind

			actualPod, err := extractPod(admissionReview)
			if err != nil {
				assert.Equal(t, tc.expectedError, err)
			} else {
				// jsons don't match exactly after marshal -> unmarshal so just check fields
				assert.Equal(t, tc.testPod.Name, actualPod.Name)
				assert.Equal(t, tc.testPod.Namespace, actualPod.Namespace)
			}
		})
	}
}

func Test_ExtractRayCluster(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		testRayCluster *rayv1.RayCluster
		expectedKind   string
		expectedError  error
	}{
		"extractRayCluster with wrong admissionRequest Kind": {
			// should return an error since Kind != RayCluster
			testRayCluster: testRayCluster.DeepCopy(),
			expectedKind:   "Pod",
			expectedError:  errors.New("Expected RayCluster but got Pod"),
		},
		"extractRayCluster with admissionRequest Kind == RayCluster": {
			// should successfully unmarshal the RayCluster object
			testRayCluster: testRayCluster.DeepCopy(),
			expectedKind:   "RayCluster",
		},
	}

	// validate that extractRayCluster correctly unmarshals admissionReview object
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			// set up admissionReview object
			admissionReview := testAdmissionReview.DeepCopy()
			jsonRayCluster, _ := json.Marshal(tc.testRayCluster)
			admissionReview.Request.Object.Raw = jsonRayCluster
			admissionReview.Request.Object.Object = tc.testRayCluster

			// set Request Kind
			admissionReview.Request.Kind.Kind = tc.expectedKind

			actualRayCluster, err := extractRayCluster(admissionReview)
			if err != nil {
				assert.Equal(t, tc.expectedError, err)
			} else {
				// jsons don't match exactly after marshal -> unmarshal so just check fields
				assert.Equal(t, tc.testRayCluster.Name, actualRayCluster.Name)
				// assert.Equal(t, tc.testRayCluster.Spec.WorkerGroupSpecs, actualRayCluster.Spec.WorkerGroupSpecs)
			}
		})
	}
}

func Test_GenDNSHostnames(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		workerGroupSpec   *rayv1.WorkerGroupSpec
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
			tc.workerGroupSpec.NumOfHosts = tc.numOfHosts
			hostnames, err := genDNSHostnames(*tc.workerGroupSpec, instanceName, namespaceStr, tc.replicaIndex)
			if err != nil {
				assert.Equal(t, tc.expectedError, err)
			} else {
				assert.Equal(t, tc.expectedHostnames, hostnames)
			}
		})
	}
}

func Test_InjectHostnames(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		numOfHosts        int
		groupName         string
		expectedSubdomain string
		expectedHostnames string
	}{
		"injectHostnames for single-host worker group": {
			// should create a patch to set the subdomain and a single TPU_WORKER_HOSTNAMES DNS hostname
			numOfHosts:        1,
			groupName:         "test-group-name",
			expectedSubdomain: fmt.Sprintf("%s-%s", instanceName, headlessServiceSuffix),
			expectedHostnames: fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 0, 0, instanceName, headlessServiceSuffix),
		},
		"injectHostnames for multi-host worker group": {
			// should create a patch to set the subdomain and TPU_WORKER_HOSTNAMES for all hosts
			numOfHosts:        1,
			groupName:         "test-group-name",
			expectedSubdomain: fmt.Sprintf("%s-%s", instanceName, headlessServiceSuffix),
			expectedHostnames: strings.Join([]string{fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 1, 0, instanceName, headlessServiceSuffix),
				fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 1, 1, instanceName, headlessServiceSuffix),
				fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 1, 2, instanceName, headlessServiceSuffix),
				fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 1, 3, instanceName, headlessServiceSuffix),
			}, ","),
		},
	}

	// check that a valid subdomain and TPU_WORKER_HOSTNAMES are injected into the Pod
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			testPod := testTPUWorker.DeepCopy()
			expectedEnv := []corev1.EnvVar{corev1.EnvVar{Name: "TPU_WORKER_HOSTNAMES", Value: tc.expectedHostnames}}
			expectedPatches := []patch{}
			injectHostnames(instanceName, tc.expectedHostnames, "/spec/containers/0/env", testPod.Spec.Containers[0], &expectedPatches)
			// check subdomain patch
			assert.Equal(t, "/spec/subdomain", expectedPatches[0]["path"])
			assert.Equal(t, tc.expectedSubdomain, expectedPatches[0]["value"])
			// check hostnames patch
			assert.Equal(t, "/spec/containers/0/env", expectedPatches[1]["path"])
			assert.Equal(t, expectedEnv, expectedPatches[1]["value"])
		})
	}
}

func Test_InjectReplicaLabel(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		replicaIndex         int
		groupName            string
		expectedReplicaLabel string
	}{
		"injectReplicaLabel with replicaIndex 0": {
			// should create a patch to set the replicaIndex label with {$WORKER_GROUP_NAME-$REPLICA_INDEX}
			replicaIndex:         0,
			groupName:            "test-group-name",
			expectedReplicaLabel: "test-group-name-0",
		},
	}

	// validate that injectReplicaLabel creates a patch with a valid replicaIndex label
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			expectedPatches := []patch{}
			injectReplicaLabel(instanceName, namespaceStr, tc.replicaIndex, tc.groupName, &expectedPatches)
			assert.Equal(t, "/metadata/labels/replicaIndex", expectedPatches[0]["path"])
			assert.Equal(t, tc.expectedReplicaLabel, expectedPatches[0]["value"])
		})
	}
}

func Test_InjectPodAffinity(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		testPod              *corev1.Pod
		replicaIndex         int
		groupName            string
		expectedReplicaLabel string
	}{
		"injectPodAffinity with replicaIndex label": {
			// should create a patch to create a podAffinity for the replicaIndex label
			testPod:              testTPUWorker.DeepCopy(),
			replicaIndex:         0,
			groupName:            "test-group-name",
			expectedReplicaLabel: "test-group-name-0",
		},
	}

	// validate that injectPodAffinity creates a patch adding a podAffinity label selector for replicaIndex
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			expectedPatches := []patch{}
			injectPodAffinity(tc.testPod, tc.replicaIndex, tc.groupName, &expectedPatches)
			patchValue := expectedPatches[0]["value"]
			affinity := patchValue.(corev1.Affinity)
			assert.Equal(t, "/spec/affinity", expectedPatches[0]["path"])
			labelValue := affinity.PodAffinity.RequiredDuringSchedulingIgnoredDuringExecution[0].LabelSelector.MatchExpressions[0].Values[0]
			assert.Equal(t, labelValue, tc.expectedReplicaLabel)
		})
	}
}

func Test_CheckWorkersMatchTopology(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		expectedNumOfHosts int32
		expectedTopology   string
		expectedTPUChips   resource.Quantity
		missingContainers  bool
		expectedError      error
		workersMatch       bool
	}{
		"checkWorkersMatchTopology NumOfHosts == 0": {
			// returns false and an error
			expectedNumOfHosts: 0,
			expectedError:      errors.New("workerGroupSpec NumOfHosts not set"),
			workersMatch:       false,
		},
		"checkWorkersMatchTopology WorkerGroup containers missing": {
			// containers == nil, returns false and an error
			missingContainers:  true,
			expectedNumOfHosts: 1,
			expectedError:      errors.New("Container path not specified"),
			workersMatch:       false,
		},
		"checkWorkersMatchTopology missing topology nodeSelector": {
			// topology not set, returns false and an error
			expectedNumOfHosts: 1,
			expectedTopology:   "",
			expectedTPUChips:   resource.MustParse("4"),
			expectedError:      errors.New("TPU topology not specified"),
			workersMatch:       false,
		},
		"checkWorkersMatchTopology NumOfHosts not equal to specified topology": {
			// topology does not match NumOfHosts, returns false
			expectedNumOfHosts: 1,
			expectedTopology:   "2x2x2",
			expectedTPUChips:   resource.MustParse("4"),
			workersMatch:       false,
		},
		"checkWorkersMatchTopology v4 single-host NumOfHosts equal to specified topology": {
			// topology matches NumOfHosts, returns true
			expectedNumOfHosts: 1,
			expectedTopology:   "2x2x1",
			expectedTPUChips:   resource.MustParse("4"),
			workersMatch:       true,
		},
		"checkWorkersMatchTopology v4 multi-host NumOfHosts equal to specified topology": {
			// topology matches NumOfHosts, returns true
			expectedNumOfHosts: 4,
			expectedTopology:   "2x2x4",
			expectedTPUChips:   resource.MustParse("4"),
			workersMatch:       true,
		},
		"checkWorkersMatchTopology v5 single-host NumOfHosts equal to specified topology": {
			// topology matches NumOfHosts, returns true
			expectedNumOfHosts: 1,
			expectedTopology:   "2x4",
			expectedTPUChips:   resource.MustParse("8"),
			workersMatch:       true,
		},
		"checkWorkersMatchTopology v5 multi-host NumOfHosts equal to specified topology": {
			// topology matches NumOfHosts, returns true
			expectedNumOfHosts: 2,
			expectedTopology:   "2x4",
			expectedTPUChips:   resource.MustParse("4"),
			workersMatch:       true,
		},
	}

	// validate checkWorkersMatchTopology returns true only when NumOfHosts == # TPU VMs specified by topology
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			// set up worker group object for test
			workerGroupSpec := testWorkerGroupSpec.DeepCopy()
			workerGroupSpec.NumOfHosts = tc.expectedNumOfHosts
			workerGroupSpec.Template.Spec.Containers[0].Resources.Limits["google.com/tpu"] = tc.expectedTPUChips
			workerGroupSpec.Template.Spec.Containers[0].Resources.Requests["google.com/tpu"] = tc.expectedTPUChips
			workerGroupSpec.Template.Spec.NodeSelector["cloud.google.com/gke-tpu-topology"] = tc.expectedTopology
			if tc.missingContainers {
				workerGroupSpec.Template.Spec.Containers = nil
			}

			workersMatchTopology, err := checkWorkersMatchTopology(instanceName, namespaceStr, *workerGroupSpec)

			if tc.expectedNumOfHosts == 0 || tc.missingContainers == true || tc.expectedTopology == "" {
				assert.Equal(t, tc.expectedError, err)
			}
			assert.Equal(t, tc.workersMatch, workersMatchTopology)
		})
	}
}

func Test_ValidateRayCluster(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		rayCluster       	*rayv1.RayCluster
		topology         	string
		numOfHosts       	int32
		replicas         	*int32
		missingWorkerGroups	bool
		expectedResponse 	*admissionv1.AdmissionResponse
		expectedAllowed  	bool
		expectedResult   	*metav1.Status
	}{
		"validateRayCluster no workerGroupSpecs": {
			// doesn't create any workergroups, pass-through
			rayCluster:      	 testRayCluster.DeepCopy(),
			topology:        	 "",
			numOfHosts:      	 int32(1),
			missingWorkerGroups: false,
			expectedAllowed: 	 true,
			expectedResult: 	 &metav1.Status{
									Status:  "Success",
									Message: "",
								},
		},
		"validateRayCluster no TPUs requested": {
			// doesn't request TPUs, pass-through
			rayCluster:      testRayCluster.DeepCopy(),
			topology:        "",
			numOfHosts:      int32(1),
			expectedAllowed: true,
			expectedResult: &metav1.Status{
				Status:  "Success",
				Message: "",
			},
		},
		"validateRayCluster worker group spec not compatible with gke-tpu-topology": {
			// request TPUs, workers don't match topology, return false
			rayCluster:      testRayCluster.DeepCopy(),
			topology:        "2x2x2",
			numOfHosts:      int32(1),
			replicas:        pointer.Int32(1),
			expectedAllowed: false,
			expectedResult: &metav1.Status{
				Status:  "Failure",
				Message: "Number of workers in worker group not equal to specified topology",
			},
		},
		"validateRayCluster RayCluster with single-slice, single-host TPU worker group": {
			// request TPUs, workers match topology, return true
			rayCluster:      testRayCluster.DeepCopy(),
			topology:        "2x2x1",
			numOfHosts:      int32(1),
			replicas:        pointer.Int32(1),
			expectedAllowed: true,
			expectedResult: &metav1.Status{
				Status:  "Success",
				Message: "",
			},
		},
		"validateRayCluster RayCluster with single-slice, multi-host TPU worker group": {
			// request TPUs, workers match topology, return true
			rayCluster:      testRayCluster.DeepCopy(),
			topology:        "2x2x4",
			numOfHosts:      int32(4),
			replicas:        pointer.Int32(1),
			expectedAllowed: true,
			expectedResult: &metav1.Status{
				Status:  "Success",
				Message: "",
			},
		},
		"validateRayCluster RayCluster with multi-slice, single-host TPU worker group": {
			// request TPUs, workers match topology, return true
			rayCluster:      testRayCluster.DeepCopy(),
			topology:        "2x2x1",
			numOfHosts:      int32(1),
			replicas:        pointer.Int32(4),
			expectedAllowed: true,
			expectedResult: &metav1.Status{
				Status:  "Success",
				Message: "",
			},
		},
		"validateRayCluster RayCluster with multi-slice, multi-host TPU worker group": {
			// request TPUs, workers match topology, return true
			rayCluster:      testRayCluster.DeepCopy(),
			topology:        "2x2x4",
			numOfHosts:      int32(4),
			replicas:        pointer.Int32(4),
			expectedAllowed: true,
			expectedResult: &metav1.Status{
				Status:  "Success",
				Message: "",
			},
		},
	}

	// check validateRayCluster
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			sliceToHostnamesCopy := deepCopySliceToHostnames()
			sliceToWorkersCopy := deepCopySliceToWorkers()

			// set up admissionReview object
			admissionReview := testAdmissionReview.DeepCopy()
			admissionReview.Request.Kind.Kind = "RayCluster"
			admissionReview.Request.Operation = "CREATE"
			// set RayCluster worker group values
			if tc.missingWorkerGroups {
				tc.rayCluster.Spec.WorkerGroupSpecs = nil
			} else {
				if tc.topology == "" {
					tc.rayCluster.Spec.WorkerGroupSpecs[0].Template.Spec.Containers[0].Resources.Limits["google.com/tpu"] = resource.MustParse("0")
					tc.rayCluster.Spec.WorkerGroupSpecs[0].Template.Spec.Containers[0].Resources.Requests["google.com/tpu"] = resource.MustParse("0")
				}
				tc.rayCluster.Spec.WorkerGroupSpecs[0].Replicas = tc.replicas
				tc.rayCluster.Spec.WorkerGroupSpecs[0].NumOfHosts = tc.numOfHosts
				tc.rayCluster.Spec.WorkerGroupSpecs[0].Template.Spec.NodeSelector["cloud.google.com/gke-tpu-topology"] = tc.topology
			}
			jsonRayCluster, _ := json.Marshal(tc.rayCluster)
			admissionReview.Request.Object.Raw = jsonRayCluster
			admissionReview.Request.Object.Object = tc.rayCluster

			// test validateRayCluster admissionResponse output
			admissionResponse, _ := validateRayCluster(admissionReview)
			if admissionResponse != nil {
				assert.Equal(t, tc.expectedAllowed, admissionResponse.Allowed)
				assert.Equal(t, tc.expectedResult.Status, admissionResponse.Result.Status)
				assert.Equal(t, tc.expectedResult.Message, admissionResponse.Result.Message)
			}

			// check that sliceToHostnames entry is generated
			if tc.topology != "" && tc.numOfHosts > 1 {
				for replicaIndex := 0; replicaIndex < int(*tc.replicas); replicaIndex++ {
					// generate TPU_WORKER_HOSTNAME values
					var expectedHostnames []string
					for hostIndex := 0; hostIndex < int(tc.numOfHosts); hostIndex++ {
						expectedHostnames = append(expectedHostnames, fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, replicaIndex, hostIndex, instanceName, headlessServiceSuffix))
					}
					// check that expectedHostnames have been set for each slice
					testSlice := slice{instanceName, groupNameStr, namespaceStr, replicaIndex, tc.numOfHosts}
					assert.Equal(t, strings.Join(expectedHostnames, ","), sliceToHostnames[testSlice])
				}
			}

			// set maps back to their previous values
			sliceToHostnames = sliceToHostnamesCopy
			sliceToWorkers = sliceToWorkersCopy
		})
	}
}

func Test_GetEnvironmentVariable(t *testing.T) {
	setupTest(t)

	// initialize test container object
	podContainer := testTPUWorker.Spec.Containers[0].DeepCopy()
	workerID := corev1.EnvVar{
		Name:  "TPU_WORKER_ID",
		Value: "0",
	}
	workerName := corev1.EnvVar{
		Name:  "TPU_NAME",
		Value: fmt.Sprintf("%s-%d", groupNameStr, 0),
	}
	workerHostnames := corev1.EnvVar{
		Name:  "TPU_WORKER_HOSTNAMES",
		Value: fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 0, 0, instanceName, headlessServiceSuffix),
	}
	podContainer.Env = []corev1.EnvVar{workerID, workerName, workerHostnames}

	tests := map[string]struct {
		variableName  string
		container     *corev1.Container
		expectedValue string
	}{
		"getEnvironmentVariable TPU_WORKER_ID": {
			// returns TPU_WORKER_ID env var value
			variableName:  "TPU_WORKER_ID",
			container:     podContainer,
			expectedValue: "0",
		},
		"getEnvironmentVariable TPU_NAME": {
			// returns TPU_NAME env var value
			variableName:  "TPU_NAME",
			container:     podContainer,
			expectedValue: fmt.Sprintf("%s-%d", groupNameStr, 0),
		},
		"getEnvironmentVariable TPU_WORKER_HOSTNAMES": {
			// returns TPU_WORKER_HOSTNAMES env var value
			variableName:  "TPU_WORKER_HOSTNAMES",
			container:     podContainer,
			expectedValue: fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 0, 0, instanceName, headlessServiceSuffix),
		},
	}

	// validate getEnvironmentVariable returns correct env var value from Pod container
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			varValue := getEnvironmentVariable(tc.variableName, *tc.container)
			assert.Equal(t, tc.expectedValue, varValue)
		})
	}
}

func Test_MutatePod(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		testPod              *corev1.Pod
		numOfHosts           int32
		missingClusterLabel  bool
		missingContainers    bool
		expectedTopology     string
		expectedTPUChips     resource.Quantity
		expectedWorkerID     string
		expectedReplicaID    int
		expectedWorkerName   string
		expectedHostnames    string
		expectedReplicaLabel string
		expectedError        error
	}{
		"mutatePod missing cluster label": {
			// missing Ray cluster label - returns error
			testPod:             testCPUWorker.DeepCopy(),
			missingClusterLabel: true,
			expectedError:       errors.New("Kuberay Pod missing RayCluster label"),
		},
		"mutatePod missing container": {
			// missing containers - returns error
			testPod:             testCPUWorker.DeepCopy(),
			missingClusterLabel: false,
			missingContainers:   true,
			expectedError:       errors.New("Container path not specified"),
		},
		"mutatePod missing gke-tpu-topology nodeSelector": {
			// requests TPUs, topology not specified - returns error
			testPod:             testTPUWorker.DeepCopy(),
			missingClusterLabel: false,
			missingContainers:   false,
			expectedTopology:    "",
			expectedError:       errors.New("TPU topology not specified"),
		},
		"mutatePod in single-host TPU worker group": {
			// requests TPUs, single-host - injects TPU_WORKER_ID, TPU_NAME and replicaIndex label
			testPod:              testTPUWorker.DeepCopy(),
			numOfHosts:           1,
			expectedTopology:     "2x2x1",
			expectedTPUChips:     resource.MustParse("4"),
			expectedWorkerID:     "0",
			expectedReplicaID:    0,
			expectedWorkerName:   fmt.Sprintf("%s-%d", groupNameStr, 0),
			expectedReplicaLabel: fmt.Sprintf("%s-%d", groupNameStr, 0),
		},
		"mutatePod in multi-host TPU worker group": {
			// requests TPUs, multi-host - injects hostname, subdomain, TPU_WORKER_ID, TPU_NAME,
			// TPU_HOSTNAMES, a podAffinity field, and the replicaIndex label
			testPod:            testTPUWorker.DeepCopy(),
			numOfHosts:         4,
			expectedTopology:   "2x2x4",
			expectedTPUChips:   resource.MustParse("4"),
			expectedWorkerID:   "0",
			expectedReplicaID:  0,
			expectedWorkerName: fmt.Sprintf("%s-%d", groupNameStr, 0),
			expectedHostnames: strings.Join([]string{fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 0, 0, instanceName, headlessServiceSuffix),
				fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 0, 1, instanceName, headlessServiceSuffix),
				fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 0, 2, instanceName, headlessServiceSuffix),
				fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 0, 3, instanceName, headlessServiceSuffix),
			}, ","),
			expectedReplicaLabel: fmt.Sprintf("%s-%d", groupNameStr, 0),
		},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			// save copy of sliceToWorkers
			sliceToWorkersCopy := deepCopySliceToWorkers()
			sliceToHostnamesCopy := deepCopySliceToHostnames()

			// set sliceToHostnames value to be injected during mutatePod
			testSlice := slice{instanceName, groupNameStr, namespaceStr, tc.expectedReplicaID, tc.numOfHosts}
			sliceToHostnames[testSlice] = tc.expectedHostnames

			// set up Pod object
			if tc.missingClusterLabel {
				tc.testPod.Labels["ray.io/cluster"] = ""
			}
			if tc.missingContainers {
				tc.testPod.Spec.Containers = nil
			}
			tc.testPod.Spec.NodeSelector["cloud.google.com/gke-tpu-topology"] = tc.expectedTopology

			if tc.expectedTopology != "" {
				tc.testPod.Spec.Containers[0].Resources.Limits["google.com/tpu"] = tc.expectedTPUChips
				tc.testPod.Spec.Containers[0].Resources.Requests["google.com/tpu"] = tc.expectedTPUChips
			}

			// set up admissionReview object
			admissionReview := testAdmissionReview.DeepCopy()
			admissionReview.Request.Kind.Kind = "Pod"
			admissionReview.Request.Operation = "CREATE"
			jsonPod, _ := json.Marshal(tc.testPod)
			admissionReview.Request.Object.Raw = jsonPod
			admissionReview.Request.Object.Object = tc.testPod

			admissionResponse, err := mutatePod(admissionReview)
			if err != nil {
				assert.Equal(t, tc.expectedError, err)
			} else {
				var patches []patch
				json.Unmarshal(admissionResponse.Patch, &patches)

				if tc.numOfHosts == 1 {
					// single-host - patches should add replicaIndex label, TPU_WORKER_ID, and TPU_NAME
					workerID := patches[1]
					workerName := patches[2]
					expectedIDPatch := []interface{}([]interface{}{map[string]interface{}{"name": "TPU_WORKER_ID", "value": tc.expectedWorkerID}})
					expectedNamePatch := []interface{}([]interface{}{map[string]interface{}{"name": "TPU_NAME", "value": tc.expectedWorkerName}})
					assert.Equal(t, tc.expectedReplicaLabel, patches[0]["value"])
					assert.Equal(t, expectedIDPatch, workerID["value"])
					assert.Equal(t, expectedNamePatch, workerName["value"])
				}
				if tc.numOfHosts > 1 {
					// multi-host - patches should add replicaIndex, hostname, podAffinity, subdomain,
					// TPU_WORKER_HOSTNAMES, TPU_WORKER_ID, and TPU_NAME
					expectedIDPatch := []interface{}([]interface{}{map[string]interface{}{"name": "TPU_WORKER_ID", "value": tc.expectedWorkerID}})
					expectedNamePatch := []interface{}([]interface{}{map[string]interface{}{"name": "TPU_NAME", "value": tc.expectedWorkerName}})
					expectedHostnamesPatch := []interface{}([]interface{}{map[string]interface{}{"name": "TPU_WORKER_HOSTNAMES", "value": tc.expectedHostnames}})
					assert.Equal(t, tc.expectedReplicaLabel, patches[0]["value"])
					assert.Equal(t, fmt.Sprintf("%s-%s", tc.expectedReplicaLabel, tc.expectedWorkerID), patches[1]["value"])
					assert.Equal(t, fmt.Sprintf("%s-%s", instanceName, headlessServiceSuffix), patches[3]["value"])
					assert.Equal(t, expectedHostnamesPatch, patches[4]["value"])
					assert.Equal(t, expectedIDPatch, patches[5]["value"])
					assert.Equal(t, expectedNamePatch, patches[6]["value"])
				}
				// reset map values after test
				sliceToWorkers = sliceToWorkersCopy
				sliceToHostnames = sliceToHostnamesCopy
			}
		})
	}
}

func Test_DeletePod(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		testPod             *corev1.Pod
		testPodSlice        slice
		testWorker          worker
		testReplicaLabel    string
		missingClusterLabel bool
		missingGroupLabel   bool
		missingContainers   bool
		missingTPUWorkerID  bool
		expectedAllowed     bool
		expectedResult      *metav1.Status
		expectedError       error
	}{
		"deletePod missing cluster label": {
			// Kuberay pod missing Ray cluster label - returns error
			testPod:             testTPUWorker.DeepCopy(),
			missingClusterLabel: true,
			expectedError:       errors.New("Kuberay Pod missing RayCluster label"),
		},
		"deletePod missing group label": {
			// Kuberay pod missing Ray worker group label - returns error
			testPod:           testTPUWorker.DeepCopy(),
			missingGroupLabel: true,
			expectedError:     errors.New("Kuberay Pod missing Ray group label"),
		},
		"deletePod missing containers": {
			// TPU Pod missing containers - returns error
			testPod:           testTPUWorker.DeepCopy(),
			testReplicaLabel:  fmt.Sprintf("%s-%d", groupNameStr, 0),
			missingContainers: true,
			expectedError:     errors.New("Pod spec missing containers"),
		},
		"deletePod missing TPU_WORKER_ID": {
			// TPU Pod missing TPU_WORKER_ID env var - returns error (since this should be set)
			testPod:            testTPUWorker.DeepCopy(),
			testReplicaLabel:   fmt.Sprintf("%s-%d", groupNameStr, 0),
			missingTPUWorkerID: true,
			expectedError:      errors.New("Unable to extract TPU_WORKER_ID"),
		},
		"deletePod non-TPU pod": {
			// missing replicaIndex label - pass-through (Pod is not from a TPU worker group)
			testPod:          testCPUWorker.DeepCopy(),
			testReplicaLabel: "",
			expectedAllowed:  true,
			expectedResult: &metav1.Status{
				Status:  "Success",
				Message: "",
			},
		},
		"deletePod TPU single-host pod": {
			// Pod is part of a single-host TPU worker group, set its worker struct isCreated value to false
			testPod:          testTPUWorker.DeepCopy(),
			testPodSlice:     slice{instanceName, groupNameStr, namespaceStr, 0, 1},
			testWorker:       worker{0, 0, true},
			testReplicaLabel: fmt.Sprintf("%s-%d", groupNameStr, 0),
			expectedAllowed:  true,
			expectedResult: &metav1.Status{
				Status:  "Success",
				Message: "",
			},
		},
		"deletePod TPU multi-host pod": {
			// Pod is part of a multi-host TPU worker group, set its worker struct isCreated value to false
			testPod:          testTPUWorker.DeepCopy(),
			testPodSlice:     slice{instanceName, groupNameStr, namespaceStr, 1, 4},
			testWorker:       worker{1, 1, true},
			testReplicaLabel: fmt.Sprintf("%s-%d", groupNameStr, 1),
			expectedAllowed:  true,
			expectedResult: &metav1.Status{
				Status:  "Success",
				Message: "",
			},
		},
	}

	// validate that deletePod "deletes" the correct worker struct from sliceToWorkers
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			// save copy of sliceToWorkers
			sliceToWorkersCopy := deepCopySliceToWorkers()

			// set up Pod object
			tc.testPod.Labels["replicaIndex"] = tc.testReplicaLabel
			if tc.missingClusterLabel {
				tc.testPod.Labels["ray.io/cluster"] = ""
			}
			if tc.missingGroupLabel {
				tc.testPod.Labels["ray.io/group"] = ""
			}
			if tc.missingContainers {
				tc.testPod.Spec.Containers = nil
			} else if !tc.missingTPUWorkerID {
				// add TPU_WORKER_ID
				tpuWorkerID := corev1.EnvVar{
					Name:  "TPU_WORKER_ID",
					Value: fmt.Sprint(tc.testWorker.workerIndex),
				}
				tc.testPod.Spec.Containers[0].Env = append(tc.testPod.Spec.Containers[0].Env, tpuWorkerID)
			}
			sliceToWorkers[tc.testPodSlice] = []worker{tc.testWorker}

			// set up admissionReview object
			admissionReview := testAdmissionReview.DeepCopy()
			admissionReview.Request.Kind.Kind = "Pod"
			admissionReview.Request.Operation = "DELETE"
			jsonPod, _ := json.Marshal(tc.testPod)
			admissionReview.Request.OldObject.Raw = jsonPod
			admissionReview.Request.OldObject.Object = tc.testPod

			admissionResponse, err := deletePod(admissionReview)
			if err != nil {
				assert.Equal(t, tc.expectedError, err)
			} else {
				var patches []patch
				json.Unmarshal(admissionResponse.Patch, &patches)

				workerIsCreated := sliceToWorkers[tc.testPodSlice][0].isCreated
				assert.False(t, workerIsCreated)
				assert.Equal(t, tc.expectedAllowed, admissionResponse.Allowed)
				assert.Equal(t, tc.expectedResult.Status, admissionResponse.Result.Status)
				assert.Equal(t, tc.expectedResult.Message, admissionResponse.Result.Message)
			}
			// reset map values after test
			sliceToWorkers = sliceToWorkersCopy
		})
	}
}
