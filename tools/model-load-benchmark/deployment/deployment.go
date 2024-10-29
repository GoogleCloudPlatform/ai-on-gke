package deployment

import (
	"bytes"
	"fmt"
	"os"
	"tool/config"

	"google.golang.org/protobuf/proto"
	v1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/serializer"
	"k8s.io/apimachinery/pkg/util/yaml"
	yamlFmt "sigs.k8s.io/yaml"
)

const (
	gcsFuseVolumeName string = "gcs-fuse-csi-ephemeral"
)

type Deployment struct {
	Config *config.Config
	Pod    *v1.Pod
}

// NewDeployment initializes a new Deployment
func NewDeployment(cfg *config.Config) (*Deployment, error) {
	d := &Deployment{Config: cfg}
	if e := d.ParsePod(); e != nil {
		return nil, fmt.Errorf("failed to setup Deployment %v", e)
	}
	d.setupDeployment()
	return d, nil
}

// ParsePod parses the base pod spec to deploy
func (d *Deployment) ParsePod() error {
	yamlData, err := os.ReadFile(d.Config.GetBasePodSpec())
	if err != nil {
		return fmt.Errorf("failed to read YAML file: %v", err)
	}
	decoder := yaml.NewYAMLOrJSONDecoder(bytes.NewReader(yamlData), 256)
	pod := &v1.Pod{}
	err = decoder.Decode(pod)
	if err != nil {
		return fmt.Errorf("failed to decode YAML: %v", err)
	}
	d.Pod = pod

	return nil
}

func (d *Deployment) setupDeployment() {
	baseAnnotations := d.Pod.GetAnnotations()
	if baseAnnotations == nil {
		baseAnnotations = map[string]string{}
	}
	filteredVolumes := []v1.Volume{}
	for _, v := range d.Pod.Spec.Volumes {
		if v.Name != gcsFuseVolumeName {
			filteredVolumes = append(filteredVolumes, v)
		}
	}
	d.Pod.Spec.Volumes = append(filteredVolumes, d.getCSIVolume())
	d.setAnnotations(baseAnnotations)
	for i := range d.Pod.Spec.Containers {
		filteredMounts := []v1.VolumeMount{}
		for _, vm := range d.Pod.Spec.Containers[i].VolumeMounts {
			if vm.Name != gcsFuseVolumeName {
				filteredMounts = append(filteredMounts, vm)
			}
		}
		d.Pod.Spec.Containers[i].VolumeMounts = filteredMounts
		d.Pod.Spec.Containers[i].VolumeMounts = append(d.Pod.Spec.Containers[i].VolumeMounts, getGcsVolMount())
	}
}

func getGcsVolMount() v1.VolumeMount {
	return v1.VolumeMount{
		Name:      gcsFuseVolumeName,
		MountPath: "/data",
	}
}

func (d *Deployment) setAnnotations(curAnnotations map[string]string) map[string]string {
	curAnnotations["gke-gcsfuse/volumes"] = "true"
	sideCarAnnotations := d.Config.SideCarResources.ToMap()
	for k, v := range sideCarAnnotations {
		curAnnotations[k] = v
	}
	return curAnnotations
}

func (d *Deployment) getCSIVolume() v1.Volume {
	return v1.Volume{
		Name: gcsFuseVolumeName,
		VolumeSource: v1.VolumeSource{
			CSI: &v1.CSIVolumeSource{
				Driver:           "gcsfuse.csi.storage.gke.io",
				ReadOnly:         proto.Bool(true),
				VolumeAttributes: d.Config.VolumeAttributes.ToMap(),
			},
		},
	}
}

// ToYAML Returns pod yaml
func (d *Deployment) ToYAML() (string, error) {
	scheme := runtime.NewScheme()
	err := v1.AddToScheme(scheme)
	if err != nil {
		return "", fmt.Errorf("failed to register scheme: %v", err)
	}

	codecs := serializer.NewCodecFactory(scheme)
	encoder := codecs.LegacyCodec(v1.SchemeGroupVersion)

	yamlBytes, err := runtime.Encode(encoder, d.Pod)
	if err != nil {
		return "", fmt.Errorf("failed to encode deployment to YAML: %v", err)
	}

	formattedYAML, err := yamlFmt.JSONToYAML(yamlBytes)
	if err != nil {
		return "", fmt.Errorf("failed to format YAML output: %v", err)
	}

	return string(formattedYAML), nil
}
