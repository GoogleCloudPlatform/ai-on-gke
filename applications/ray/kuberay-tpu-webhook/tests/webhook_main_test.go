package main

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	ray "github.com/ray-project/kuberay/ray-operator/apis/ray/v1"
	admissionv1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/klog/v2"
)

var (
	namespaceStr                   string
	instanceName                   string
	groupNameStr                   string
	testPodAdmissionReviews        *admissionv1.AdmissionReview
	testCPUPods                    []runtime.Object
	testTPUPods                    []runtime.Object
	testRayClusterAdmissionReviews *admissionv1.AdmissionReview
	testRayClusterNoTPUs           *rayv1.RayCluster
	testRayClusterSingleHostTPU    *rayv1.RayCluster
	testRayClusterMultiHostTPU     *rayv1.RayCluster
	testServices                   []runtime.Object
	workerSelector                 labels.Selector
	headNodeIP                     string
)

func setupTest(t *testing.T) {
	logf.SetLogger(zap.New(zap.WriteTo(GinkgoWriter), zap.UseDevMode(true)))
	namespaceStr = "default"
	instanceName = "raycluster-sample"
	headNodeIP = "1.2.3.4"
	groupNameStr = "workergroup"

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
								cpu:                 "1",
								google.com / tpu:    "4",
								memory:              "40G",
								ephemeral - storage: "20Gi",
							},
							Requests: corev1.ResourceList{
								cpu:                 "1",
								google.com / tpu:    "4",
								memory:              "40G",
								ephemeral - storage: "20Gi",
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
								cpu:                 "1",
								google.com / tpu:    "4",
								memory:              "40G",
								ephemeral - storage: "20Gi",
							},
							Requests: corev1.ResourceList{
								cpu:                 "1",
								google.com / tpu:    "4",
								memory:              "40G",
								ephemeral - storage: "20Gi",
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
								cpu:                 "1",
								google.com / tpu:    "4",
								memory:              "40G",
								ephemeral - storage: "20Gi",
							},
							Requests: corev1.ResourceList{
								cpu:                 "1",
								google.com / tpu:    "4",
								memory:              "40G",
								ephemeral - storage: "20Gi",
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
								cpu:                 "1",
								google.com / tpu:    "4",
								memory:              "40G",
								ephemeral - storage: "20Gi",
							},
							Requests: corev1.ResourceList{
								cpu:                 "1",
								google.com / tpu:    "4",
								memory:              "40G",
								ephemeral - storage: "20Gi",
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

	testPodAdmissionReviews = &admissionv1.AdmissionReview{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Pod",
			APIVersion: "v1",
		},
		Request: &admissionv1.AdmissionRequest{
			UID: "uid",
			Kind: metav1.GroupVersionKind{
				Group:   "",
				Version: "v1",
				Kind:    "Pod",
			},
			Resource: metav1.GroupVersionResource{
				Group:    "",
				Version:  "v1",
				Resource: "Pod",
			},
			// Object: runtime.RawExtension{
			// 	Raw:    json.Marshal(testCPUPods),
			// 	Object: testCPUPods,
			// },
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

func Test_ContainerRequestingTPUs(t *testing.T) {
	setupTest(t)

}

func Test_GetNumTPUHostsFromTopology(t *testing.T) {
	setupTest(t)

}

func Test_IsTPUMultiHost(t *testing.T) {
	setupTest(t)

}

func Test_ExtractRayCluster(t *testing.T) {
	setupTest(t)

}

func Test_GetDNSHostnames(t *testing.T) {
	setupTest(t)

}

func Test_InjectHostnames(t *testing.T) {
	setupTest(t)

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

func Test_GetReplicaIndex(t *testing.T) {
	setupTest(t)

}

func Test_GetNextWorkerID(t *testing.T) {
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

}
