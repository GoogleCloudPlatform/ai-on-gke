package gcsfuse

import "fmt"

var defaultMountOptions = "implicit-dirs"
var defaultVolumeAttributes = map[string]string{
	"bucketName":             "vertex-model-garden-public-us",
	"mountOptions":           defaultMountOptions,
	"gcsfuseLoggingSeverity": "warning",
}
var defaultPodAnnotations = map[string]string{
	"gke-gcsfuse/volumes": "true",
}

// Options struct holds configuration options for GCSFuse.
type Options struct {
	BucketName     string    // bucketName
	Mode           MountMode // mode ("persistent" or "ephemeral")
	PerfOptions    *PerfOptions
	SideCarOptions *SideCarOptions
}

type SideCarOptions struct {
	CPULimit                string `json:"cpu-limit"`                 // CPU limit (e.g., "10" means 10 CPUs)
	MemoryLimit             string `json:"memory-limit"`              // Memory limit (e.g., "10Gi")
	EphemeralStorageLimit   string `json:"ephemeral-storage-limit"`   // Ephemeral storage limit (e.g., "1Ti")
	CPURequest              string `json:"cpu-request"`               // CPU request (e.g., "500m" means 0.5 CPUs)
	MemoryRequest           string `json:"memory-request"`            // Memory request (e.g., "1Gi")
	EphemeralStorageRequest string `json:"ephemeral-storage-request"` // Ephemeral storage request (e.g., "50Gi")
}

// MountMode defines the type for 'mode' field in Options.
type MountMode string

// Constants representing valid mount modes.
const (
	Persistent MountMode = "persistent"
	Ephemeral  MountMode = "ephemeral"
)

type PerfOptions struct {
	MountOptions     *MountOptions
	VolumeAttributes *VolumeAttributes
}

// MountOptions represents additional mount options for GCSFuse.
type MountOptions struct {
	CacheStatInterval  string // -o stat_cache_interval
	FileCacheOptions   *FileCacheOptions
	SequentialReadSize int // --sequential-read-size-mb
}

// FileCacheOptions represents file caching options for GCSFuse.
type FileCacheOptions struct {
	EnableParallelDownloads  bool // file-cache:enable-parallel-downloads
	ParallelDownloadsPerFile int  // file-cache:parallel-downloads-per-file
	MaxParallelDownloads     int  // file-cache:max-parallel-downloads
	DownloadChunkSizeMB      int  // file-cache:download-chunk-size-mb
}

// VolumeAttributes represents the gcsfuse volume attributes impacting performance.
type VolumeAttributes struct {
	GCSFuseLoggingSeverity    string // gcsfuseLoggingSeverity
	FileCacheCapacity         string // fileCacheCapacity in Gi
	FileCacheForRangeRead     bool   // fileCacheForRangeRead
	MetadataStatCacheCapacity string // metadataStatCacheCapacity
	MetadataTypeCacheCapacity string // metadataTypeCacheCapacity
	MetadataCacheTTLSeconds   string // metadataCacheTTLSeconds
}

func (options *Options) ToMap() (map[string]string, map[string]string) {
	return options.PerfOptions.ToMap(), options.SideCarOptions.ToMap()
}

func (perfOptions *PerfOptions) ToMap() map[string]string {
	result := defaultVolumeAttributes
	if perfOptions == nil {
		return result
	}
	if perfOptions.VolumeAttributes != nil {
		result = defaultVolumeAttributes
	}
	if perfOptions.MountOptions != nil {
		result["mountOptions"] = perfOptions.MountOptions.ToString()
	}
	return result
}

func (volumeAttributes *VolumeAttributes) ToMap() map[string]string {
	res := defaultVolumeAttributes
	if volumeAttributes.FileCacheCapacity != "" {
		res["fileCacheCapacity"] = volumeAttributes.FileCacheCapacity
	}
	if volumeAttributes.FileCacheForRangeRead {
		res["FileCacheForRangeRead"] = fmt.Sprintf("%v", volumeAttributes.FileCacheCapacity)
	}
	if volumeAttributes.MetadataCacheTTLSeconds != "" {
		res["MetadataCacheTTLSeconds"] = volumeAttributes.MetadataCacheTTLSeconds
	}
	if volumeAttributes.MetadataStatCacheCapacity != "" {
		res["MetadataStatCacheCapacity"] = volumeAttributes.MetadataStatCacheCapacity
	}
	if volumeAttributes.MetadataTypeCacheCapacity != "" {
		res["MetadataTypeCacheCapacity"] = volumeAttributes.MetadataTypeCacheCapacity
	}
	return res
}

// ToMap converts the SideCarOptions struct to a map[string]string.
func (options *SideCarOptions) ToMap() map[string]string {
	if options == nil {
		return defaultPodAnnotations
	}
	return map[string]string{
		"gke-gcsfuse/cpu-limit":                 options.CPULimit,
		"gke-gcsfuse/memory-limit":              options.MemoryLimit,
		"gke-gcsfuse/ephemeral-storage-limit":   options.EphemeralStorageLimit,
		"gke-gcsfuse/cpu-request":               options.CPURequest,
		"gke-gcsfuse/memory-request":            options.MemoryRequest,
		"gke-gcsfuse/ephemeral-storage-request": options.EphemeralStorageRequest,
	}
}

// Convert MountOptions to a string representation
func (mountOptions *MountOptions) ToString() string {

	// Base mount options string (e.g., DirMode)
	mountOptionsStr := defaultMountOptions

	// Add file cache options if present
	if mountOptions.FileCacheOptions != nil {
		mountOptionsStr += fmt.Sprintf(
			",file-cache:enable-parallel-downloads:%v,file-cache:parallel-downloads-per-file:%v,file-cache:max-parallel-downloads:%v,file-cache:download-chunk-size-mb:%v",
			mountOptions.FileCacheOptions.EnableParallelDownloads,
			mountOptions.FileCacheOptions.ParallelDownloadsPerFile,
			mountOptions.FileCacheOptions.MaxParallelDownloads,
			mountOptions.FileCacheOptions.DownloadChunkSizeMB,
		)
	}

	// Add sequential read size if applicable
	if mountOptions.SequentialReadSize > 0 {
		mountOptionsStr += fmt.Sprintf(",sequential-read-size-mb:%d", mountOptions.SequentialReadSize)
	}

	// Add cache stat interval if it's not empty
	if mountOptions.CacheStatInterval != "" {
		mountOptionsStr += fmt.Sprintf(",stat_cache_interval:%s", mountOptions.CacheStatInterval)
	}

	return mountOptionsStr
}
