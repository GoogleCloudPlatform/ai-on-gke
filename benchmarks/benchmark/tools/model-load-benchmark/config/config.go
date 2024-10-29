package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"gopkg.in/yaml.v2"
)

// Config for a deployment
type Config struct {
	BasePodSpec      string            `yaml:"basePodSpec"`
	SideCarResources *SideCarResources `yaml:"sideCarResources"`
	VolumeAttributes *VolumeAttributes `yaml:"volumeAttributes"`
}

// SideCarResources contains GCSFuse sidecar resources
type SideCarResources struct {
	CPULimit                Resource `yaml:"cpu-limit"`
	MemoryLimit             Resource `yaml:"memory-limit"`
	EphemeralStorageLimit   Resource `yaml:"ephemeral-storage-limit"`
	CPURequest              Resource `yaml:"cpu-request"`
	MemoryRequest           Resource `yaml:"memory-request"`
	EphemeralStorageRequest Resource `yaml:"ephemeral-storage-request"`
}

// VolumeAttributes contains fuse configurations through mount options and attributes
type VolumeAttributes struct {
	BucketName                string       `yaml:"bucketName"`
	MountOptions              MountOptions `yaml:"mountOptions"`
	FileCacheCapacity         Resource     `yaml:"fileCacheCapacity"`
	FileCacheForRangeRead     bool         `yaml:"fileCacheForRangeRead"`
	MetadataStatCacheCapacity Resource     `yaml:"metadataStatCacheCapacity"`
	MetadataTypeCacheCapacity Resource     `yaml:"metadataTypeCacheCapacity"`
	MetadataCacheTTLSeconds   Resource     `yaml:"metadataCacheTTLSeconds"`
}

// MountOptions contains file cache arguments and other fuse cli args
type MountOptions struct {
	ImplicitDirs bool      `yaml:"implicit-dirs"`
	OnlyDir      string    `yaml:"only-dir"`
	FileCache    FileCache `yaml:"file-cache"`
}

// FileCache contains file cache related fuse cli options
type FileCache struct {
	EnableParallelDownloads  bool     `yaml:"enable-parallel-downloads"`
	ParallelDownloadsPerFile Resource `yaml:"parallel-downloads-per-file"`
	MaxParallelDownloads     Resource `yaml:"max-parallel-downloads"`
	DownloadChunkSizeMB      Resource `yaml:"download-chunk-size-mb"`
}

type Resource struct {
	Base int    `yaml:"base"`
	Step int    `yaml:"step,omitempty"`
	Max  int    `yaml:"max"`
	Unit string `yaml:"unit,omitempty"`
}

// UnmarshalYAML custom unmarshal for Resource
func (r *Resource) UnmarshalYAML(unmarshal func(interface{}) error) error {
	rawData := make(map[string]interface{})
	if err := unmarshal(&rawData); err != nil {
		return err
	}

	if baseVal, ok := rawData["base"].(string); ok {
		base, unit := parseValueUnit(baseVal)
		r.Base = base
		r.Unit = unit
	} else if baseVal, ok := rawData["base"].(int); ok {
		r.Base = baseVal
	}

	if stepVal, ok := rawData["step"].(int); ok {
		r.Step = stepVal
	}

	if maxVal, ok := rawData["max"].(string); ok {
		max, maxUnit := parseValueUnit(maxVal)
		if maxUnit != "" && maxUnit != r.Unit {
			return fmt.Errorf("unit mismatch between base and max: base unit is %s, but max unit is %s", r.Unit, maxUnit)
		}
		r.Max = max
	} else if maxVal, ok := rawData["max"].(int); ok {
		r.Max = maxVal
	}

	r.setDefaults()
	return nil
}

func (r *Resource) setDefaults() {
	if r.Step == 0 {
		r.Step = 1
	}
	if r.Max == 0 {
		r.Max = r.Base
	}
}

// UnmarshalYAML custom unmarshal for MountOptions
func (mo *MountOptions) UnmarshalYAML(unmarshal func(interface{}) error) error {
	data := make(map[string]interface{})
	err := unmarshal(&data)
	if err != nil {
		return err
	}

	for key, value := range data {
		switch key {
		case "implicit-dirs":
			mo.ImplicitDirs, _ = value.(bool)
		case "only-dir":
			mo.OnlyDir, _ = value.(string)
		case "file-cache":
			cacheData, err := yaml.Marshal(value)
			if err != nil {
				return fmt.Errorf("error marshalling file-cache data: %v", err)
			}
			err = yaml.Unmarshal(cacheData, &mo.FileCache)
			if err != nil {
				return fmt.Errorf("error unmarshalling file-cache: %v", err)
			}
		default:
			fmt.Printf("Warning: unrecognized key in mountOptions: %s\n", key)
		}
	}
	return nil
}

// LoadConfig loads the configuration from a YAML file
func LoadConfig(filename string) (*Config, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	config := &Config{}
	err = yaml.Unmarshal(data, config)
	if err != nil {
		return nil, err
	}
	if config.BasePodSpec == "" {
		return nil, fmt.Errorf("missing or empty required field 'BasePodSpec'")
	}
	// Validate that VolumeAttributes and bucketName are set
	if config.VolumeAttributes == nil || config.VolumeAttributes.BucketName == "" {
		return nil, fmt.Errorf("missing or empty required field 'volumeAttributes.bucketName'")
	}

	// Validate that only-dir is set
	if config.VolumeAttributes.MountOptions.OnlyDir == "" {
		return nil, fmt.Errorf("invalid value for 'mountOptions.only-dir': must be set and cannot be '0'")
	}

	return config, nil
}

// PrettyPrint in formatted YAML string
func (c *Config) PrettyPrint() (string, error) {
	yamlData, err := yaml.Marshal(c)
	if err != nil {
		return "", fmt.Errorf("failed to marshal config to YAML: %v", err)
	}
	return string(yamlData), nil
}

// ToMountOptionsString outputs formatted string for Mount options attribute under volume mount
func (m *MountOptions) ToMountOptionsString() string {
	options := []string{}

	if m.ImplicitDirs {
		options = append(options, "implicit-dirs")
	}
	if m.OnlyDir != "" {
		options = append(options, fmt.Sprintf("only-dir=%s", m.OnlyDir))
	}

	options = append(options,
		fmt.Sprintf("file-cache:enable-parallel-downloads:%v", m.FileCache.EnableParallelDownloads),
		fmt.Sprintf("file-cache:download-chunk-size-mb:%v", m.FileCache.DownloadChunkSizeMB.Base),
	)
	if m.FileCache.EnableParallelDownloads {
		options = append(options,
			fmt.Sprintf("file-cache:parallel-downloads-per-file:%v", m.FileCache.ParallelDownloadsPerFile.Base),
			fmt.Sprintf("file-cache:max-parallel-downloads:%v", m.FileCache.MaxParallelDownloads.Base))
	}

	return strings.Join(options, ",")
}

func (v *VolumeAttributes) ToMap() map[string]string {
	volAttributes := make(map[string]string)

	if v.BucketName != "" {
		volAttributes["bucketName"] = v.BucketName
	}

	volAttributes["mountOptions"] = v.MountOptions.ToMountOptionsString()

	volAttributes["fileCacheCapacity"] = fmt.Sprintf("%d%s", v.FileCacheCapacity.Base, v.FileCacheCapacity.Unit)
	volAttributes["metadataStatCacheCapacity"] = fmt.Sprintf("%d%s", v.MetadataStatCacheCapacity.Base, v.MetadataStatCacheCapacity.Unit)
	volAttributes["metadataTypeCacheCapacity"] = fmt.Sprintf("%d%s", v.MetadataTypeCacheCapacity.Base, v.MetadataTypeCacheCapacity.Unit)
	volAttributes["metadataCacheTTLSeconds"] = fmt.Sprintf("%d%s", v.MetadataCacheTTLSeconds.Base, v.MetadataCacheTTLSeconds.Unit)

	volAttributes["fileCacheForRangeRead"] = strconv.FormatBool(v.FileCacheForRangeRead)

	return volAttributes
}

// ToMap convert sidecar resources to annotations parsed by GCSFuse Sidecar
func (s *SideCarResources) ToMap() map[string]string {
	annotations := map[string]string{
		"gke-gcsfuse/volumes": "true",
	}
	if s.CPULimit.Base != 0 {
		annotations["gke-gcsfuse/cpu-limit"] = fmt.Sprintf("%d%s", s.CPULimit.Base, s.CPULimit.Unit)
	}
	if s.MemoryLimit.Base != 0 {
		annotations["gke-gcsfuse/memory-limit"] = fmt.Sprintf("%d%s", s.MemoryLimit.Base, s.MemoryLimit.Unit)
	}
	if s.EphemeralStorageLimit.Base != 0 {
		annotations["gke-gcsfuse/ephemeral-storage-limit"] = fmt.Sprintf("%d%s", s.EphemeralStorageLimit.Base, s.EphemeralStorageLimit.Unit)
	}
	if s.CPURequest.Base != 0 {
		annotations["gke-gcsfuse/cpu-request"] = fmt.Sprintf("%d%s", s.CPURequest.Base, s.CPURequest.Unit)
	}
	if s.MemoryRequest.Base != 0 {
		annotations["gke-gcsfuse/memory-request"] = fmt.Sprintf("%d%s", s.MemoryRequest.Base, s.MemoryRequest.Unit)
	}
	if s.EphemeralStorageRequest.Base != 0 {
		annotations["gke-gcsfuse/ephemeral-storage-request"] = fmt.Sprintf("%d%s", s.EphemeralStorageRequest.Base, s.EphemeralStorageRequest.Unit)
	}

	return annotations
}

func (c *Config) GetBasePodSpec() string {
	return c.BasePodSpec
}
