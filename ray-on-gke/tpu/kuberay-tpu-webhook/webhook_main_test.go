package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"strings"
	"testing"

	rayv1 "github.com/ray-project/kuberay/ray-operator/apis/ray/v1"
	"github.com/ray-project/kuberay/ray-operator/controllers/ray/utils"
	"github.com/stretchr/testify/assert"
	admissionv1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/client-go/informers"
	"k8s.io/client-go/kubernetes/fake"
	listersv1 "k8s.io/client-go/listers/core/v1"
	"k8s.io/client-go/tools/cache"
	"k8s.io/utils/pointer"
)

var (
	namespaceStr           string
	instanceName           string
	groupNameStr           string
	headGroupNameStr       string
	testCPUWorker          *corev1.Pod
	testTPUWorker          *corev1.Pod
	testCPUPods            []*corev1.Pod
	testTPUPods            []*corev1.Pod
	testInterceptedTPUPods []*corev1.Pod
	testAdmissionReview    *admissionv1.AdmissionReview
	testRayCluster         *rayv1.RayCluster
	headNodeIP             string
	testWorkerGroupSpec    *rayv1.WorkerGroupSpec
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

	// add 4 TPU worker pods with env vars set
	numOfHosts := 2
	numSlices := 2
	podIndex := 0
	testInterceptedTPUPods = []*corev1.Pod{}
	for i := 0; i < numSlices; i++ {
		// generate hostnames for this slice
		hostnames := make([]string, numOfHosts)
		for ind := 0; ind < numOfHosts; ind++ {
			hostnames[i] = fmt.Sprintf("%s-%d-%d", groupNameStr, i, ind)
		}
		testHostnames := strings.Join(hostnames, ",")
		replicaIndex := fmt.Sprintf("%s-%d", groupNameStr, i)
		for j := 0; j < numOfHosts; j++ {
			testTPUWorkerCopy := testTPUWorker.DeepCopy()
			// set TPU environment variables for this Pod
			env := []corev1.EnvVar{
				{
					Name:  "TPU_WORKER_ID",
					Value: fmt.Sprint(j),
				},
				{
					Name:  "TPU_WORKER_HOSTNAMES",
					Value: testHostnames,
				},
				{
					Name:  "TPU_NAME",
					Value: replicaIndex,
				},
			}
			testTPUWorkerCopy.Spec.Containers[0].Env = env
			testTPUWorkerCopy.Name = fmt.Sprintf("%s-%d", "intercepted-tpu-pod", podIndex)
			podIndex += 1
			testTPUWorkerCopy.Labels["replicaIndex"] = replicaIndex
			testInterceptedTPUPods = append(testInterceptedTPUPods, testTPUWorkerCopy)
		}
	}
}

// sets up a PodInformer, waits for cache to sync, and returns the Informer PodLister
func setupInformer(pods []*corev1.Pod) listersv1.PodLister {
	// initialize fake Clientset with pod objects
	tpuObjects := make([]runtime.Object, len(pods))
	for i, pod := range pods {
		tpuObjects[i] = pod
	}
	fakeClientSet := fake.NewSimpleClientset(tpuObjects...)

	// initialize podLister using the fake client for testing
	factory := informers.NewSharedInformerFactory(fakeClientSet, 0)
	podInformer := factory.Core().V1().Pods().Informer()

	stopCh := make(chan struct{})
	defer close(stopCh)

	factory.Start(stopCh)
	factory.WaitForCacheSync(stopCh)

	// wait for cache to sync before creating the Lister
	if !cache.WaitForCacheSync(stopCh, podInformer.HasSynced) {
		fmt.Printf("Timed out waiting for fake client to sync")
		return nil
	}

	return factory.Core().V1().Pods().Lister()
}

func Test_GetReplicaIndex(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		numOfHosts            int32
		numReplicas           int
		additionalGroupStr    string
		additionalNumOfHosts  int32
		additionalNumReplicas int
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
	}

	// validate getReplicaIndex() returns the expected Replica ID for TPU pods in varying pod slices
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			sliceToWorkerIDs := make(map[slice][]int)
			for i := 0; i < tc.numReplicas; i++ {
				testPodSlice := slice{instanceName, groupNameStr, namespaceStr, i, tc.numOfHosts}
				for j := 0; j < int(tc.numOfHosts); j++ {
					replicaIndex := getReplicaIndex(sliceToWorkerIDs, instanceName, groupNameStr, namespaceStr)
					assert.Equal(t, i, replicaIndex)

					// add the worker ID to sliceToWorkerIDs - this would happen in getNextWorkerID
					if sliceToWorkerIDs[testPodSlice] == nil {
						sliceToWorkerIDs[testPodSlice] = []int{j}
					} else {
						sliceToWorkerIDs[testPodSlice] = append(sliceToWorkerIDs[testPodSlice], j)
					}
				}
			}
			// test assigning pods to replicas for a different worker group
			if tc.additionalGroupStr != "" {
				for i := 0; i < tc.additionalNumReplicas; i++ {
					testAdditionalPodSlice := slice{instanceName, tc.additionalGroupStr, namespaceStr, i, tc.additionalNumOfHosts}
					for j := 0; j < int(tc.additionalNumOfHosts); j++ {
						replicaIndex := getReplicaIndex(sliceToWorkerIDs, instanceName, tc.additionalGroupStr, namespaceStr)
						assert.Equal(t, i, replicaIndex)

						// add the worker ID to sliceToWorkerIDs - this would happen in getNextWorkerID
						if sliceToWorkerIDs[testAdditionalPodSlice] == nil {
							sliceToWorkerIDs[testAdditionalPodSlice] = []int{j}
						} else {
							sliceToWorkerIDs[testAdditionalPodSlice] = append(sliceToWorkerIDs[testAdditionalPodSlice], j)
						}
					}
				}
			}
			assert.Equal(t, tc.numReplicas+tc.additionalNumReplicas, len(sliceToWorkerIDs))
		})
	}
}

func Test_GetNextWorkerID(t *testing.T) {
	setupTest(t)

	tests := map[string]struct {
		numOfHosts            int32
		numReplicas           int
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
	}

	// validate getNextWorkerID() returns the expected TPU_WORKER ID for different worker group configurations
	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			sliceToWorkerIDs := make(map[slice][]int)
			for replicaIndex := 0; replicaIndex < tc.numReplicas; replicaIndex++ {
				testPodSlice := slice{instanceName, groupNameStr, namespaceStr, replicaIndex, tc.numOfHosts}
				for j := 0; j < int(tc.numOfHosts); j++ {
					workerID := getNextWorkerID(sliceToWorkerIDs, testPodSlice, namespaceStr, replicaIndex)
					if sliceToWorkerIDs[testPodSlice] == nil {
						sliceToWorkerIDs[testPodSlice] = []int{j}
					} else {
						sliceToWorkerIDs[testPodSlice] = append(sliceToWorkerIDs[testPodSlice], j)
					}
					assert.Equal(t, j, workerID)
				}
			}
			// test assigning TPU_WORKER_IDs to pods for a different worker group
			if tc.additionalGroupStr != "" {
				for i := 0; i < tc.additionalNumReplicas; i++ {
					testAdditionalPodSlice := slice{instanceName, tc.additionalGroupStr, namespaceStr, i, tc.additionalNumOfHosts}
					for j := 0; j < int(tc.additionalNumOfHosts); j++ {
						workerID := getNextWorkerID(sliceToWorkerIDs, testAdditionalPodSlice, namespaceStr, i)
						assert.Equal(t, j, workerID)
					}
				}
			}
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
		replicaIndex      int
		numOfHosts        int32
		expectedHostnames string
		expectedError     error
	}{
		"genDNSHostnames with NumOfHosts == 0": {
			// a workergroup can't have NumOfHosts set to 0 so this should error out
			replicaIndex:  0,
			numOfHosts:    int32(0),
			expectedError: errors.New("workerGroupSpec NumOfHosts not set"),
		},
		"genDNSHostnames with NumOfHosts == 1": {
			// Single-host worker group, should return a single DNS hostname. This function will
			// never be called for single-host groups, but we don't necessarily want it to error if it does.
			replicaIndex:      0,
			numOfHosts:        int32(1),
			expectedHostnames: fmt.Sprintf("%s-%d-%d.%s-%s", groupNameStr, 0, 0, instanceName, headlessServiceSuffix),
		},
		"genDNSHostnames with NumOfHosts > 1": {
			// multi-host worker group, should return a string list of DNS hostnames for the given replica
			replicaIndex: 1,
			numOfHosts:   int32(4),
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
			hostnames, err := genDNSHostnames(tc.numOfHosts, groupNameStr, instanceName, namespaceStr, tc.replicaIndex)
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
		rayCluster          *rayv1.RayCluster
		topology            string
		numOfHosts          int32
		replicas            *int32
		missingWorkerGroups bool
		expectedResponse    *admissionv1.AdmissionResponse
		expectedAllowed     bool
		expectedResult      *metav1.Status
	}{
		"validateRayCluster no workerGroupSpecs": {
			// doesn't create any workergroups, pass-through
			rayCluster:          testRayCluster.DeepCopy(),
			topology:            "",
			numOfHosts:          int32(1),
			missingWorkerGroups: false,
			expectedAllowed:     true,
			expectedResult: &metav1.Status{
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

func Test_GetSliceToWorkerIDs(t *testing.T) {
	setupTest(t)

	testPodLister := setupInformer(testInterceptedTPUPods)

	tests := map[string]struct {
		podLister           listersv1.PodLister
		numOfHosts          int32
		numReplicas         int
		expectedPodsInGroup []*corev1.Pod
		expectedWorkerID    string
		expectedError       error
	}{
		"getSliceToWorkerIDs missing PodLister": {
			// PodLister is not initialized - returns error
			podLister:     nil,
			expectedError: errors.New("k8s Pod Informer Lister not initialized"),
		},
		"getSliceToWorkerIDs for with TPU pod list": {
			// sliceToWorkerIDs should be populated with TPU worker IDs
			podLister:           testPodLister,
			numOfHosts:          int32(2),
			numReplicas:         2,
			expectedPodsInGroup: testInterceptedTPUPods,
		},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			sliceToWorkerIDs, err := getSliceToWorkerIDs(tc.podLister, instanceName, groupNameStr, namespaceStr, tc.numOfHosts)

			if tc.expectedError != nil {
				assert.Equal(t, tc.expectedError, err)
			} else {
				// sliceToWorkerIDs should be populated with slices and unique TPU_WORKER_IDs for each Pod
				assert.Equal(t, err, nil)
				assert.Equal(t, tc.numReplicas, len(sliceToWorkerIDs))
				for i := 0; i < tc.numReplicas; i++ {
					testPodSlice := slice{instanceName, groupNameStr, namespaceStr, i, tc.numOfHosts}
					workerIDs := sliceToWorkerIDs[testPodSlice]
					sort.Ints(workerIDs)
					assert.Equal(t, int(tc.numOfHosts), len(workerIDs))
					for j := 0; j < int(tc.numOfHosts); j++ {
						assert.Equal(t, j, workerIDs[j])
					}
				}
			}
		})
	}
}

func Test_MutatePod(t *testing.T) {
	setupTest(t)

	testPodLister := setupInformer(testTPUPods)

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

			admissionResponse, err := mutatePod(testPodLister, admissionReview)
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
			}
		})
	}
}
