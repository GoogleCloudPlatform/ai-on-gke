package suitegenerator

import (
	"reflect"
	"testing"
	"tool/config"

	"github.com/stretchr/testify/assert"
)

// Helper function to create the base config with limited variations
func createBaseConfig() config.Config {
	return config.Config{
		BasePodSpec: "example-pod.yaml",
		SideCarResources: &config.SideCarResources{
			CPULimit:                config.Resource{Base: 20, Max: 20, Step: 5},
			MemoryLimit:             config.Resource{Base: 2048, Max: 2048, Step: 1024},
			EphemeralStorageLimit:   config.Resource{Base: 50, Max: 50, Step: 10},
			CPURequest:              config.Resource{Base: 200, Max: 250, Step: 50},
			MemoryRequest:           config.Resource{Base: 1024, Max: 1024, Step: 2},
			EphemeralStorageRequest: config.Resource{Base: 40, Max: 40, Step: 10},
		},
		VolumeAttributes: &config.VolumeAttributes{
			BucketName: "example-bucket",
			MountOptions: config.MountOptions{
				ImplicitDirs: true,
				OnlyDir:      "example-dir",
				FileCache: config.FileCache{
					EnableParallelDownloads:  true,
					ParallelDownloadsPerFile: config.Resource{Base: 4, Max: 4, Step: 1},
					MaxParallelDownloads:     config.Resource{Base: 0, Max: 0},
					DownloadChunkSizeMB:      config.Resource{Base: 0, Max: 0},
				},
			},
			FileCacheCapacity:         config.Resource{Base: 10, Max: 10, Step: 2},
			FileCacheForRangeRead:     true,
			MetadataStatCacheCapacity: config.Resource{Base: 0, Max: 0},
			MetadataTypeCacheCapacity: config.Resource{Base: 0, Max: 0},
			MetadataCacheTTLSeconds:   config.Resource{Base: 0, Max: 0},
		},
	}
}

func TestGenerateCases(t *testing.T) {
	baseConfig := createBaseConfig()
	suite := GenerateCases(baseConfig)

	// Define the expected case as per the configuration you provided
	expectedCase := config.Config{
		BasePodSpec: "example-pod.yaml",
		SideCarResources: &config.SideCarResources{
			CPULimit:                config.Resource{Base: 20, Max: 20, Step: 5},
			MemoryLimit:             config.Resource{Base: 2048, Max: 2048, Step: 1024},
			EphemeralStorageLimit:   config.Resource{Base: 50, Max: 50, Step: 10},
			CPURequest:              config.Resource{Base: 200, Max: 250, Step: 50},
			MemoryRequest:           config.Resource{Base: 1024, Max: 1024, Step: 2},
			EphemeralStorageRequest: config.Resource{Base: 40, Max: 40, Step: 10},
		},
		VolumeAttributes: &config.VolumeAttributes{
			BucketName: "example-bucket",
			MountOptions: config.MountOptions{
				ImplicitDirs: true,
				OnlyDir:      "example-dir",
				FileCache: config.FileCache{
					EnableParallelDownloads:  true,
					ParallelDownloadsPerFile: config.Resource{Base: 4, Max: 4, Step: 1},
					MaxParallelDownloads:     config.Resource{Base: 0, Max: 0},
					DownloadChunkSizeMB:      config.Resource{Base: 0, Max: 0},
				},
			},
			FileCacheCapacity:         config.Resource{Base: 10, Max: 10, Step: 2},
			FileCacheForRangeRead:     true,
			MetadataStatCacheCapacity: config.Resource{Base: 0, Max: 0},
			MetadataTypeCacheCapacity: config.Resource{Base: 0, Max: 0},
			MetadataCacheTTLSeconds:   config.Resource{Base: 0, Max: 0},
		},
	}

	t.Run("Check specific case existence", func(t *testing.T) {
		assert.True(t, containsCase(suite.Cases, expectedCase), "Expected case not found in generated cases")
	})
}

// Helper function to check if a specific case exists in the generated cases
func containsCase(cases []config.Config, expected config.Config) bool {
	for _, testCase := range cases {
		if reflect.DeepEqual(testCase, expected) {
			return true
		}
	}
	return false
}

func TestNormalizeToBaseUnit(t *testing.T) {
	tests := []struct {
		name     string
		value    int
		unit     string
		expected int
	}{
		{"Gi to Ki", 1, "Gi", 1_024 * 1_024},
		{"Mi to Ki", 1, "Mi", 1_024},
		{"m to m", 100, "m", 100},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := normalizeToBaseUnit(tt.value, tt.unit)
			assert.NoError(t, err)
			assert.Equal(t, tt.expected, result)
		})
	}
}

// Helper function to identify unique cases
func uniqueCases(cases []config.Config) map[string]bool {
	unique := make(map[string]bool)
	for _, testCase := range cases {
		yamlStr, _ := testCase.PrettyPrint()
		unique[yamlStr] = true
	}
	return unique
}
