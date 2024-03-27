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
	"k8s.io/utils/pointer"

	"github.com/stretchr/testify/assert"
	// "github.com/GoogleCloudPlatform/kuberay-tpu-webhook"
)

var (
	namespaceStr                  string
	instanceName                  string
	groupNameStr                  string
	headGroupNameStr              string
	testPodAdmissionReviews       *admissionv1.AdmissionReview
	testCPUPods                   []runtime.Object
	testTPUPods                   []runtime.Object
	testRayClusterAdmissionReview *admissionv1.AdmissionReview
	testRayClusterNoTPUs          *rayv1.RayCluster
	testRayClusterSingleHostTPU   *rayv1.RayCluster
	testRayClusterMultiHostTPU    *rayv1.RayCluster
	testServices                  []runtime.Object
	workerSelector                labels.Selector
	headNodeIP                    string
	// sliceToWorkers				  map[slice][]worker
	numOfHosts  int32
	numReplicas int
)

func setupTest(t *testing.T) {
	namespaceStr = "default"
	instanceName = "raycluster-sample"
	headNodeIP = "1.2.3.4"
	groupNameStr = "workergroup"
	headlessServiceSuffix = "headless-worker-svc"

	// 1 CPU head pod + 1 worker - doesn't request TPUs
	testCPUPods = []runtime.Object{
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
	testTPUPods = []runtime.Object{
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
}

func Test_GetReplicaIndex(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		sliceToWorkers     map[slice][]worker
		numOfHosts         int32
		numReplicas        int
		additionalGroupStr string
		numOfHosts2        int32
		numReplicas2       int
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
			numOfHosts:         4,
			numReplicas:        4,
			additionalGroupStr: "another-worker-group",
			numOfHosts2:        2,
			numReplicas2:       3,
		},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			sliceToWorkers = make(map[slice][]worker)
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
			if tc.additionalGroupStr != "" {
				for i := 0; i < tc.numReplicas2; i++ {
					testPodSlice := slice{instanceName, tc.additionalGroupStr, namespaceStr, i, tc.numOfHosts2}
					for j := 0; j < int(tc.numOfHosts2); j++ {
						replicaIndex := getReplicaIndex(instanceName, tc.additionalGroupStr, namespaceStr)
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
			}
			assert.Equal(t, tc.numReplicas+tc.numReplicas2, len(sliceToWorkers))
		})
	}
}

func Test_GetNextWorkerID(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		numOfHosts  int32
		numReplicas int
		deletePodID int
	}{
		"single-host, single-slice worker group": {
			// single-slice, replicaIndex should always be 0
			numOfHosts:  1,
			numReplicas: 1,
			deletePodID: -1,
		},
		"single-host, multi-slice worker group": {
			// multi-slice, replicaIndex should always be 0-numReplicas
			numOfHosts:  1,
			numReplicas: 4,
			deletePodID: -1,
		},
		"multi-host, single-slice worker group": {
			// single-slice, replicaIndex should always be 0
			numOfHosts:  4,
			numReplicas: 1,
			deletePodID: -1,
		},
		"multi-host, multi-slice worker group": {
			// multi-slice, replicaIndex should always be 0-numReplicas for 0-numOfHosts pods
			numOfHosts:  4,
			numReplicas: 4,
			deletePodID: -1,
		},
		"deleted pod from multi-host group": {
			// pod should be reassigned the ID of the deleted pod
			numOfHosts:  4,
			numReplicas: 4,
			deletePodID: 2,
		},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			sliceToWorkers = make(map[slice][]worker)
			for i := 0; i < tc.numReplicas; i++ {
				testPodSlice := slice{instanceName, groupNameStr, namespaceStr, i, tc.numOfHosts}
				for j := 0; j < int(tc.numOfHosts); j++ {
					workerID := getNextWorkerID(testPodSlice, namespaceStr, i)
					assert.Equal(t, j, workerID)
				}
			}
			if tc.deletePodID != -1 {
				testPodSlice := slice{instanceName, groupNameStr, namespaceStr, 0, tc.numOfHosts}
				sliceToWorkers[testPodSlice][tc.deletePodID].isCreated = false
				workerID := getNextWorkerID(testPodSlice, namespaceStr, 0)
				assert.Equal(t, tc.deletePodID, workerID)
			}
		})
	}
}
