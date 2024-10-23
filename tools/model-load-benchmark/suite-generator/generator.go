package suitegenerator

import (
	"fmt"
	"math"
	gcsfuse "tool/gcs-fuse"
)

type Suite struct {
	name       string
	totalSize  float32
	numFiles   int
	fileSize   *distribution // size in bytes
	bucketName int
	vcpu       float32 //in millicores e.g 103670m
	memory     float32 // in Kib
	storage    float32 // in bytes
}

type distribution struct {
	percentile25 float32
	percentile75 float32
	median       float32
}

func (suite *Suite) generate() []*gcsfuse.Options {

	return nil
}

func (suite *Suite) fileCacheOptionsGenerator() []*gcsfuse.FileCacheOptions {
	return nil
}

// SideCarOptionsGenerator generates SideCarOptions based on the Suite properties.
func (suite *Suite) SideCarOptionsGenerator() []*gcsfuse.SideCarOptions {
	const maxMemoryPercentage = 0.1 // 10% of total memory
	const maxVCPUPercentage = 0.1   // 10% of total vCPU
	const maxMemoryForSidecar = 0.2 // 20% of total size in memory

	// Define minimum resource requirements
	const minCPUMin = 250.0                              // Minimum CPU request in millicores
	const minMemoryMin = 256.0                           // Minimum memory request in MiB
	const minEphemeralStorage = 5.0 * 1024 * 1024 * 1024 // 5 GiB in bytes

	// Calculate the total memory available for the sidecar
	maxMemory := float64(suite.memory * maxMemoryPercentage)
	maxVCPU := float32(math.Ceil(float64(suite.vcpu) * maxVCPUPercentage))

	// Calculate ephemeral storage request
	ephemeralStorageRequest := math.Max(float64(suite.totalSize), float64(suite.storage)*0.1)

	// Ensure that the ephemeral storage request meets the minimum requirement
	ephemeralStorageRequest = math.Max(ephemeralStorageRequest, minEphemeralStorage)

	// Percentiles to consider
	percentiles := []float32{
		suite.fileSize.percentile25,
		suite.fileSize.median,
		suite.fileSize.percentile75,
	}

	var sideCarOptionsList []*gcsfuse.SideCarOptions

	for _, fileSize := range percentiles {
		// Calculate number of vCPUs based on file size
		if fileSize <= 0 {
			fileSize = 1 // Avoid division by zero
		}
		requiredVCPUs := float32(suite.totalSize / fileSize)

		// Ensure sidecar vCPU does not exceed limits
		if requiredVCPUs > maxVCPU {
			requiredVCPUs = maxVCPU
		}

		// Calculate memory for sidecar based on total size
		sidecarMemory := math.Min(maxMemory, float64(suite.totalSize)*maxMemoryForSidecar)

		// Ensure the sidecar memory meets minimum requirements
		if sidecarMemory < minMemoryMin {
			sidecarMemory = minMemoryMin
		}

		// Create SideCarOptions
		sideCarOptions := &gcsfuse.SideCarOptions{
			CPULimit:                fmt.Sprintf("%.0f", requiredVCPUs),                                     // Total CPUs needed
			MemoryLimit:             fmt.Sprintf("%.0fGi", sidecarMemory/(1024*1024)),                       // Convert KiB to GiB
			EphemeralStorageLimit:   "1Ti",                                                                  // Example static value
			CPURequest:              fmt.Sprintf("%.0fm", math.Max(float64(requiredVCPUs)*1000, minCPUMin)), // Convert to millicores, ensure min
			MemoryRequest:           fmt.Sprintf("%.0fGi", sidecarMemory/(1024*1024)),                       // Convert KiB to GiB
			EphemeralStorageRequest: fmt.Sprintf("%.0fGi", ephemeralStorageRequest/(1024*1024*1024)),        // Request based on max of total size or 10% of storage
		}

		// Append the generated SideCarOptions to the list
		sideCarOptionsList = append(sideCarOptionsList, sideCarOptions)
	}

	return sideCarOptionsList
}

func (suite *Suite) fileCacheDownloadChunkSizeMb() []int {
	// Helper to calculate chunk size for each percentile
	calculateChunkSize := func(fileSizeInBytes float32) int {
		// Convert file size from bytes to MiB (1 MiB = 1024 * 1024 bytes)
		fileSizeInMiB := fileSizeInBytes / (1024 * 1024)

		// Divide file size by vCPU (in cores, hence divide by 1000) to get chunk size in MiB
		vCPUInCores := suite.vcpu / 1000
		chunkSize := int(math.Ceil(float64(fileSizeInMiB) / float64(vCPUInCores)))

		// Calculate the memory limit per vCPU in MiB
		// Convert memory from KiB to MiB (1 MiB = 1024 KiB)
		maxMemoryLimit := int(math.Ceil(float64(suite.memory) / 1024 / float64(vCPUInCores*2)))

		if chunkSize > maxMemoryLimit {
			return maxMemoryLimit // Choose minimum if chunk size exceeds memory constraints
		}
		return chunkSize
	}

	// Calculate chunk sizes for each percentile in MiB
	chunkSize25th := calculateChunkSize(suite.fileSize.percentile25)
	chunkSize75th := calculateChunkSize(suite.fileSize.percentile75)
	chunkSizeMedian := calculateChunkSize(suite.fileSize.median)

	// Return the chunk sizes for 25th, median, and 75th percentiles
	return []int{chunkSize25th, chunkSizeMedian, chunkSize75th}
}
