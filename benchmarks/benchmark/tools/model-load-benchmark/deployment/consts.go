package deployment

import (
	v1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	"k8s.io/apimachinery/pkg/util/intstr"
)

const (
	AppLabel             = "llm-server"
	NamespaceDefault     = "default"
	ImageInferenceServer = "us-docker.pkg.dev/vertex-ai/vertex-vision-model-garden-dockers/pytorch-vllm-serve:20240821_1034_RC00"
	TargetPort           = 7080
	ServicePort          = 8000
)

var (
	dshmVolume = v1.Volume{
		Name: "dshm",
		VolumeSource: v1.VolumeSource{
			EmptyDir: &v1.EmptyDirVolumeSource{
				Medium: v1.StorageMediumMemory,
			},
		},
	}
	livenessProbe = &v1.Probe{
		ProbeHandler: v1.ProbeHandler{
			HTTPGet: &v1.HTTPGetAction{
				Path: "/health",
				Port: intstr.IntOrString{IntVal: ServicePort},
			},
		},
		InitialDelaySeconds: 60,
		PeriodSeconds:       10,
	}
	readinessProbe = &v1.Probe{
		ProbeHandler: v1.ProbeHandler{
			HTTPGet: &v1.HTTPGetAction{
				Path: "/health",
				Port: intstr.IntOrString{IntVal: ServicePort},
			},
		},
		InitialDelaySeconds: 60,
		PeriodSeconds:       5,
	}
	volumeMounts = []v1.VolumeMount{
		{Name: "gcs-fuse-csi-ephemeral", MountPath: "/data", ReadOnly: true},
		{Name: "dshm", MountPath: "/dev/shm"},
	}
	modelResources = map[string]v1.ResourceRequirements{
		"llama-3-1-8b": {
			Requests: v1.ResourceList{
				"cpu":               resource.MustParse("8"),
				"memory":            resource.MustParse("29Gi"),
				"ephemeral-storage": resource.MustParse("80Gi"),
				"nvidia.com/gpu":    resource.MustParse("1"),
			},
			Limits: v1.ResourceList{
				"cpu":               resource.MustParse("8"),
				"memory":            resource.MustParse("29Gi"),
				"ephemeral-storage": resource.MustParse("80Gi"),
				"nvidia.com/gpu":    resource.MustParse("1"),
			},
		},
		"llama-3-1-70b": {
			Requests: v1.ResourceList{
				"cpu":               resource.MustParse("58"),
				"memory":            resource.MustParse("231Gi"),
				"ephemeral-storage": resource.MustParse("200Gi"),
				"nvidia.com/gpu":    resource.MustParse("8"),
			},
			Limits: v1.ResourceList{
				"cpu":               resource.MustParse("58"),
				"memory":            resource.MustParse("231Gi"),
				"ephemeral-storage": resource.MustParse("200Gi"),
				"nvidia.com/gpu":    resource.MustParse("8"),
			},
		},
	}
)
