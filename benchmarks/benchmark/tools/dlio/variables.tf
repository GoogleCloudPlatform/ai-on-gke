# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "namespace" {
  type        = string
  description = "Kubernetes namespace where resources are deployed"
  default     = "benchmark"
}

variable "k8s_service_account" {
  type        = string
  description = "Kubernetes service account name as in the Configure access to Cloud Storage buckets using GKE Workload Identity step"
  default     = "benchmark-ksa"
}

variable "gcs_bucket" {
  type        = string
  description = "GCS Bucket name"
  default     = "<your gcs bucket>"
}

variable "result_bucket" {
  type        = string
  description = "GCS Bucket name to store dlio results"
  default     = "<result bucket>"
}

// at most one of the below trigers can be set to true
variable "run_with_gcs_fuse_csi" {
  type        = string
  description = "Set to true if running DLIO on GCSFuse"
  default     = "\"true\""
}

variable "run_with_parallelstore_csi" {
  type        = string
  description = "Set to true if running DLIO on Parallelstore and the Parallelstore CSI driver is enabled on your cluster"
  default     = "\"false\""
}
// at most one of the above triggeres can be set to true

// DLIO Job configurations
variable "job_backoffLimit" {
  type        = number
  description = "The number of retries before considering a Job as failed"
  default     = 0
}

variable "job_completions" {
  type        = number
  description = "The number of Pods that are successful while the Job is considered to be complete"
  default     = 1
}

variable "job_parallelism" {
  type        = number
  description = "The desired number of Pods to run in parallel for a Job. Kubernetes will ensure that no more than this number of Pods are running at any given time."
  default     = 1
}

variable "gcs_fuse_sidecar_cpu_limit" {
  type        = string
  description = "The maximum amount of CPU resource that the sidecar container can use"
  default     = "\"20\""
}

variable "gcs_fuse_sidecar_memory_limit" {
  type        = string
  description = "The maximum amount of Memory resource that the sidecar container can use"
  default     = "\"20Gi\""
}

variable "gcs_fuse_sidecar_ephemeral_storage_limit" {
  type        = string
  description = "The maximum amount of Ephemeral Storage resource that the sidecar container can use"
  default     = "\"100Gi\""
}

variable "pscsi_sidecar_cpu_limit" {
  type        = string
  description = "The maximum amount of CPU resource that the sidecar container can use"
  default     = "\"20\""
}

variable "pscsi_sidecar_memory_limit" {
  type        = string
  description = "The maximum amount of Memory resource that the sidecar container can use"
  default     = "\"20Gi\""
}

variable "dlio_container_cpu_limit" {
  type        = number
  description = "The maximum amount of CPU resource that the DLIO benchmark workload container can use"
  default     = "30"
}

variable "dlio_container_memory_limit" {
  type        = string
  description = "The maximum amount of Memory resource that the DLIO benchmark workload container can use"
  default     = "150Gi"
}

variable "dlio_container_ephemeral_storage" {
  type        = string
  description = "The maximum amount of Ephemeral Storage resource that the DLIO benchmark workload container can use"
  default     = "100Gi"
}

variable "dlio_data_mount_path" {
  type        = string
  description = "The path where your GCS bucket volume or other volume is mounted"
  default     = "/data"
}

variable "dlio_benchmark_result" {
  type        = string
  description = "The path stores benchmark result reports for a specific DLIO run. When doing multi-pod runs, this folder stores results logged from all the pods, needs to be changed every run to guarantee result isolation."
  default     = "<a result folder name unique to your run>"
}

// DLIO configurations, detailed explanation check
// https://github.com/argonne-lcf/dlio_benchmark
// https://argonne-lcf.github.io/dlio_benchmark/config.html
variable "dlio_generate_data" {
  type        = string
  description = "Set to True to generate dataset. Set to False to perform data train"
  default     = "False"
}

variable "dlio_number_of_processors" {
  type        = number
  description = "The number of processors used to run the task"
  default     = 8
}

variable "dlio_model" {
  type        = string
  description = "Specifying the name of the model"
  default     = "unet3d"
}

variable "dlio_record_length" {
  type        = number
  description = "Size of each sample"
  default     = "150000000"
}

variable "dlio_record_length_stdev" {
  type        = number
  description = "Standard deviation of the size of samples"
  default     = 0
}

variable "dlio_record_length_resize" {
  type        = number
  description = "Resized sample size"
  default     = 0
}

variable "dlio_number_of_files" {
  type        = number
  description = "Number of files for the training set"
  default     = 5000
}

variable "dlio_profiler" {
  type        = string
  description = "Specifying the profiler to use [none|iostat|tensorflow|pytorch]"
  default     = "none"
}

variable "dlio_iostat_devices" {
  type        = string
  description = "Specifying the devices to perform iostat tracing"
  default     = ""
}

variable "dlio_batch_size" {
  type        = number
  description = "Batch size for training"
  default     = 4
}

variable "dlio_train_epochs" {
  type        = number
  description = "Number of epochs to simulate"
  default     = 1
}

variable "dlio_read_threads" {
  type        = number
  description = "Number of threads to load the data (for tensorflow and pytorch data loader)"
  default     = 10
}

// pv, pvc
variable "pv_name" {
  type        = string
  description = "Name of the PersistentVolume used for DLIO dataset"
  default     = "benchmark-pv"
}

variable "pvc_name" {
  type        = string
  description = "Name of the PersistentVolumeClaim used for DLIO dataset"
  default     = "benchmark-pvc"
}

// gcsfuse cache configurations
variable "gcsfuse_stat_cache_capacity" {
  type        = string
  description = "Size of the Cloud Storage Fuse stat cache. Set value to 0 to disable the stat cache"
  default     = "20000"
}

variable "gcsfuse_stat_cache_ttl" {
  type        = string
  description = "Specifies how long Cloud Storage FUSE caches stat entries"
  default     = "120m0s"
}

variable "gcsfuse_type_cache_ttl" {
  type        = string
  description = "Specifies how long Cloud Storage FUSE caches the mapping of objects in Cloud Storage to their corresponding type, such as files or directories"
  default     = "120m0s"
}

// parallelstore variables
variable "run_parallelstore_data_loader" {
  type        = string
  description = "Set to true if running the dataloader for parallelstore"
  default     = "\"true\""
}

variable "parallelstore_instance_name" {
  type        = string
  description = "instance name of parallelstore"
  default     = "<instance name>"
}

// The IPs are listed as "accessPoints" in the result of instance describe command
variable "parallelstore_ip_address_1" {
  type        = string
  description = "ip address of the parallelstore instance's accessPoints"
  default     = "<ip-address>"
}

variable "parallelstore_ip_address_2" {
  type        = string
  description = "ip address of the parallelstore instance's accessPoints"
  default     = "<ip-address>"
}

variable "parallelstore_ip_address_3" {
  type        = string
  description = "ip address of the parallelstore instance's accessPoints"
  default     = "<ip-address>"
}

variable "parallelstore_network_name" {
  type        = string
  description = "network name of the parallelstore instance"
  default     = "<network name>"
}

variable "parallelstore_location" {
  type        = string
  description = "location of the parallelstore instance, e.g. us-central1-a"
  default     = "<location>"
}

variable "parallelstore_storageclass" {
  type        = string
  description = "the storage class used for dynamic provisioning. if using static provisioning, set it to nil"
  default     = "parallelstore-rwx"
}

variable "parallelstore_project" {
  type        = string
  description = "the project name of the parallelstore instance"
  default     = "<project name>"
}
