package k8sclient

import (
	gcsfuse "tool/gcs-fuse"

	"google.golang.org/protobuf/proto"
	appsv1 "k8s.io/api/apps/v1"
	v1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	intstr "k8s.io/apimachinery/pkg/util/intstr"
)

// Function to return the predefined deployment
func GetMistral7BDeployment() *appsv1.Deployment {
	return &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "mistral-7b",
			Namespace: "default",
			Labels: map[string]string{
				"app": "mistral-7b",
			},
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: int32Ptr(1),
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app": "mistral-7b",
				},
			},
			Template: v1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app": "mistral-7b",
					},
				},
				Spec: v1.PodSpec{
					Volumes: []v1.Volume{
						{
							Name: "cache-volume",
							VolumeSource: v1.VolumeSource{
								PersistentVolumeClaim: &v1.PersistentVolumeClaimVolumeSource{
									ClaimName: "mistral-7b",
								},
							},
						},
						{
							Name: "shm",
							VolumeSource: v1.VolumeSource{
								EmptyDir: &v1.EmptyDirVolumeSource{
									Medium:    v1.StorageMediumMemory,
									SizeLimit: resourceQuantity("2Gi"),
								},
							},
						},
					},
					Containers: []v1.Container{
						{
							Name:    "mistral-7b",
							Image:   "vllm/vllm-openai:latest",
							Command: []string{"/bin/sh", "-c"},
							Args: []string{
								"vllm serve mistralai/Mistral-7B-Instruct-v0.3 --trust-remote-code --enable-chunked-prefill --max_num_batched_tokens 1024",
							},
							Env: []v1.EnvVar{
								{
									Name: "HUGGING_FACE_HUB_TOKEN",
									ValueFrom: &v1.EnvVarSource{
										SecretKeyRef: &v1.SecretKeySelector{
											LocalObjectReference: v1.LocalObjectReference{
												Name: "hf-token-secret",
											},
											Key: "token",
										},
									},
								},
							},
							Ports: []v1.ContainerPort{
								{
									ContainerPort: 8000,
								},
							},
							Resources: v1.ResourceRequirements{
								Limits: v1.ResourceList{
									"cpu":            *resourceQuantity("10"),
									"memory":         *resourceQuantity("20Gi"),
									"nvidia.com/gpu": *resourceQuantity("1"),
								},
								Requests: v1.ResourceList{
									"cpu":            *resourceQuantity("2"),
									"memory":         *resourceQuantity("6Gi"),
									"nvidia.com/gpu": *resourceQuantity("1"),
								},
							},
							VolumeMounts: []v1.VolumeMount{
								{
									Name:      "cache-volume",
									MountPath: "/root/.cache/huggingface",
								},
								{
									Name:      "shm",
									MountPath: "/dev/shm",
								},
							},
							LivenessProbe: &v1.Probe{
								ProbeHandler: v1.ProbeHandler{
									HTTPGet: &v1.HTTPGetAction{
										Path: "/health",
										Port: intstr.IntOrString{IntVal: 8000},
									},
								},
								InitialDelaySeconds: 60,
								PeriodSeconds:       10,
							},
							ReadinessProbe: &v1.Probe{
								ProbeHandler: v1.ProbeHandler{
									HTTPGet: &v1.HTTPGetAction{
										Path: "/health",
										Port: intstr.IntOrString{IntVal: 8000},
									},
								},
								InitialDelaySeconds: 60,
								PeriodSeconds:       5,
							},
						},
					},
				},
			},
		},
	}
}

// Function to return the predefined meta deployment
func GetMetaLlamaDeployment(options *gcsfuse.Options) *appsv1.Deployment {
	// Extract the GCSFuse mount options and performance options from the provided options
	// Get the bucket name from the Options struct
	volAttributes := options.ToMap()
	// pass directory to options only-dir=relative/path/to/the/bucket/root
	return &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "meta-server",
			Namespace: "default",
			Labels: map[string]string{
				"app": "meta-server",
			},
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: int32Ptr(1),
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app": "meta-server",
				},
			},
			Template: v1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app":                        "meta-server",
						"ai.gke.io/model":            "Llama-3-1-8B",
						"ai.gke.io/inference-server": "vllm",
						"examples.ai.gke.io/source":  "model-garden",
					},
					Annotations: map[string]string{
						"gke-gcsfuse/volumes": "true", // Add the annotation here
					},
				},
				Spec: v1.PodSpec{
					Containers: []v1.Container{
						{
							Name:  "inference-server",
							Image: "us-docker.pkg.dev/vertex-ai/vertex-vision-model-garden-dockers/pytorch-vllm-serve:20240821_1034_RC00",
							Resources: v1.ResourceRequirements{
								Requests: v1.ResourceList{
									"cpu":               *resourceQuantity("8"),
									"memory":            *resourceQuantity("29Gi"),
									"ephemeral-storage": *resourceQuantity("80Gi"),
									"nvidia.com/gpu":    *resourceQuantity("1"),
								},
								Limits: v1.ResourceList{
									"cpu":               *resourceQuantity("8"),
									"memory":            *resourceQuantity("29Gi"),
									"ephemeral-storage": *resourceQuantity("80Gi"),
									"nvidia.com/gpu":    *resourceQuantity("1"),
								},
							},
							Command: []string{"python", "-m", "vllm.entrypoints.api_server"},
							Args: []string{
								"--host=0.0.0.0",
								"--port=7080",
								"--swap-space=16",
								"--gpu-memory-utilization=0.9",
								"--max-model-len=32768",
								"--trust-remote-code",
								"--disable-log-stats",
								"--model=/data/llama3.2/Llama-3.2-1B",
								"--tensor-parallel-size=1",
								"--max-num-seqs=12",
								"--enforce-eager",
								"--disable-custom-all-reduce",
								"--enable-chunked-prefill",
							},
							VolumeMounts: []v1.VolumeMount{
								{
									Name:      "gcs-fuse-csi-ephemeral",
									MountPath: "/data",
									ReadOnly:  true,
								},
								{
									Name:      "dshm",
									MountPath: "/dev/shm",
								},
							},
						},
					},
					Volumes: []v1.Volume{
						{
							Name: "gcs-fuse-csi-ephemeral",
							VolumeSource: v1.VolumeSource{
								CSI: &v1.CSIVolumeSource{
									Driver:           "gcsfuse.csi.storage.gke.io",
									ReadOnly:         proto.Bool(true),
									VolumeAttributes: volAttributes,
								},
							},
						},
						{
							Name: "dshm",
							VolumeSource: v1.VolumeSource{
								EmptyDir: &v1.EmptyDirVolumeSource{
									Medium: v1.StorageMediumMemory,
								},
							},
						},
					},
					NodeSelector: map[string]string{
						"cloud.google.com/gke-accelerator": "nvidia-h100-80gb",
					},
				},
			},
		},
	}
}

// Function to return the predefined service for Meta-Llama-3.1-8B
func GetMetaLlamaService() *v1.Service {
	return &v1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "meta-service",
			Namespace: "default",
			Labels: map[string]string{
				"app": "meta-server",
			},
		},
		Spec: v1.ServiceSpec{
			Selector: map[string]string{
				"app": "meta-server",
			},
			Type: v1.ServiceTypeClusterIP, // Set the service type to ClusterIP
			Ports: []v1.ServicePort{
				{
					Protocol:   v1.ProtocolTCP,
					Port:       8000,                             // The port exposed by the service
					TargetPort: intstr.IntOrString{IntVal: 7080}, // The port on the container to forward requests to
				},
			},
		},
	}
}

func int32Ptr(i int32) *int32 {
	return &i
}

func resourceQuantity(q string) *resource.Quantity {
	quantity, err := resource.ParseQuantity(q)
	if err != nil {
		panic(err)
	}
	return &quantity
}
