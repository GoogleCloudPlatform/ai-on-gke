package config

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
	"gopkg.in/yaml.v2"
)

// Mock YAML data for testing
var mockYAML = `
basePodSpec: "example-pod.yaml"
sideCarResources:
  cpu-limit: 
    base: 20
    max: 25
    step: 5
  memory-limit: 
    base: 2Gi
    max: 2Gi
    step: 20
  ephemeral-storage-limit: 
    base: 50Gi
    max: 50Gi
    step: 20
  cpu-request: 
    base: 200m
    max: 200m
    step: 50
  memory-request: 
    base: 1Gi 
    max: 1Gi 
    step: 2
  ephemeral-storage-request: 
    base: 40Gi
    max: 40Gi
    step: 10
volumeAttributes:
  bucketName: "vertex-model-garden-public-us"
  mountOptions:
    implicit-dirs: true
    only-dir: "codegemma/codegemma-2b"
    file-cache:
      enable-parallel-downloads: true
      parallel-downloads-per-file: 
        base: 4
        step: 5
        max: 5
      max-parallel-downloads: 
        base: 2
        step: 5 
        max: 3
      download-chunk-size-mb: 
        base: 3
        step: 5 
        max: 5
  fileCacheCapacity: 
    base: 10Gi
    step: 2
    max: 10Gi
  fileCacheForRangeRead: true
  metadataStatCacheCapacity: 
    base: 500Mi
    step: 20
    max: 500Mi
  metadataTypeCacheCapacity: 
    base: 500Mi
    step: 20
    max: 520Mi
  metadataCacheTTLSeconds: 
    base: 600
    step: 20
    max: 620
`

func loadMockConfig() (*Config, error) {
	config := &Config{}
	err := yaml.Unmarshal([]byte(mockYAML), config)
	return config, err
}

func TestLoadConfig(t *testing.T) {
	tests := []struct {
		desc     string
		key      string
		expected interface{}
		actual   interface{}
	}{
		{"BasePodSpec should be 'example-pod.yaml'", "BasePodSpec", "example-pod.yaml", config.BasePodSpec},
		{"BucketName should be 'vertex-model-garden-public-us'", "BucketName", "vertex-model-garden-public-us", config.VolumeAttributes.BucketName},
	}

	for _, test := range tests {
		t.Run(test.desc, func(t *testing.T) {
			assert.Equal(t, test.expected, test.actual, fmt.Sprintf("%s does not match", test.key))
		})
	}
}

func TestResourceUnmarshal(t *testing.T) {
	data := `
base: "20Gi"
max: "25Gi"
`
	resource := &Resource{}
	err := yaml.Unmarshal([]byte(data), resource)
	assert.NoError(t, err)

	tests := []struct {
		desc     string
		key      string
		expected interface{}
		actual   interface{}
	}{
		{"Resource base should be 20", "Base", 20, resource.Base},
		{"Resource max should be 25", "Max", 25, resource.Max},
		{"Resource unit should be 'Gi'", "Unit", "Gi", resource.Unit},
	}

	for _, test := range tests {
		t.Run(test.desc, func(t *testing.T) {
			assert.Equal(t, test.expected, test.actual, fmt.Sprintf("%s does not match", test.key))
		})
	}
}

func TestMountOptionsUnmarshal(t *testing.T) {
	config, err := loadMockConfig()
	assert.NoError(t, err)

	tests := []struct {
		desc     string
		expected interface{}
		actual   interface{}
	}{
		{"ImplicitDirs should be true", true, config.VolumeAttributes.MountOptions.ImplicitDirs},
		{"OnlyDir should be 'codegemma/codegemma-2b'", "codegemma/codegemma-2b", config.VolumeAttributes.MountOptions.OnlyDir},
	}

	for _, test := range tests {
		t.Run(test.desc, func(t *testing.T) {
			assert.Equal(t, test.expected, test.actual)
		})
	}
}

func TestToMountOptionsString(t *testing.T) {
	config, err := loadMockConfig()
	assert.NoError(t, err)

	mountOptions := config.VolumeAttributes.MountOptions
	expected := "implicit-dirs,only-dir=codegemma/codegemma-2b,file-cache:enable-parallel-downloads:true,file-cache:download-chunk-size-mb:3"
	t.Run("MountOptions string does not match expected format", func(t *testing.T) {
		assert.Equal(t, expected, mountOptions.ToMountOptionsString())
	})
}

func TestVolumeAttributesToMap(t *testing.T) {
	config, err := loadMockConfig()
	assert.NoError(t, err)

	volMap := config.VolumeAttributes.ToMap()
	tests := []struct {
		desc     string
		key      string
		expected string
	}{
		{"Bucket name does not match expected value", "bucketName", "vertex-model-garden-public-us"},
		{"File cache capacity does not match expected value", "fileCacheCapacity", "10Gi"},
		{"Metadata stat cache capacity does not match expected value", "metadataStatCacheCapacity", "500Mi"},
		{"Metadata type cache capacity does not match expected value", "metadataTypeCacheCapacity", "500Mi"},
		{"Metadata cache TTL seconds does not match expected value", "metadataCacheTTLSeconds", "600s"},
		{"File cache for range read should be true", "fileCacheForRangeRead", "true"},
	}

	for _, test := range tests {
		t.Run(test.desc, func(t *testing.T) {
			assert.Equal(t, test.expected, volMap[test.key])
		})
	}
}

func TestSideCarResourcesToMap(t *testing.T) {
	config, err := loadMockConfig()
	assert.NoError(t, err)

	sideCarMap := config.SideCarResources.ToMap()
	tests := []struct {
		desc     string
		key      string
		expected string
	}{
		{"CPU limit does not match expected value", "gke-gcsfuse/cpu-limit", "20"},
		{"Memory limit does not match expected value", "gke-gcsfuse/memory-limit", "2Gi"},
		{"Ephemeral storage limit does not match expected value", "gke-gcsfuse/ephemeral-storage-limit", "50Gi"},
		{"CPU request does not match expected value", "gke-gcsfuse/cpu-request", "200m"},
		{"Memory request does not match expected value", "gke-gcsfuse/memory-request", "1Gi"},
		{"Ephemeral storage request does not match expected value", "gke-gcsfuse/ephemeral-storage-request", "40Gi"},
	}

	for _, test := range tests {
		t.Run(test.desc, func(t *testing.T) {
			assert.Equal(t, test.expected, sideCarMap[test.key])
		})
	}
}

func TestPrettyPrint(t *testing.T) {
	config, err := loadMockConfig()
	assert.NoError(t, err)

	yamlStr, err := config.PrettyPrint()
	assert.NoError(t, err)

	tests := []struct {
		desc     string
		expected string
	}{
		{"YAML output should contain 'example-pod.yaml'", "example-pod.yaml"},
		{"YAML output should contain 'vertex-model-garden-public-us'", "vertex-model-garden-public-us"},
	}

	for _, test := range tests {
		t.Run(test.desc, func(t *testing.T) {
			assert.Contains(t, yamlStr, test.expected)
		})
	}
}
