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

	// 1 head pod + 1 worker - doesn't request TPUs
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

}

func Test_ContainerRequestingTPUs() {

}

func Test_GetNumTPUHostsFromTopology() {

}

func Test_IsTPUMultiHost() {

}

func Test_ExtractRayCluster() {

}

func Test_GetDNSHostnames() {

}

func Test_InjectHostnames() {

}

func Test_InjectMultiHostReplicaLabel() {

}

func Test_InjectPodAffinity() {

}

func Test_CheckWorkersMatchTopology() {

}

func Test_ValidateRayCluster() {

}

func Test_GetEnvironmentVariable() {

}

func Test_GetReplicaIndex() {

}

func Test_GetNextWorkerID() {

}

func Test_ExtractPod() {

}

func Test_MutatePod() {

}

func Test_DeletePod() {

}
