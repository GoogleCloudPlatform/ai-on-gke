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
}

variable "k8s_service_account" {
  type        = string
  description = "Kubernetes service account name as in the Configure access to Cloud Storage buckets using GKE Workload Identity step"
}

variable "gcs_bucket" {
  type        = string
  description = "GCS Bucket name"
}

variable "pvc_name" {
  type        = string
  description = "Name of the PersistentVolumeClaim used for DLIO dataset"
}

// DLIO Job configurations
variable "job_backoffLimit" {
  type        = number
  description = "The number of retries before considering a Job as failed"
}

variable "job_completions" {
  type        = number
  description = "The number of Pods that are successful while the Job is considered to be complete"
}

variable "job_parallelism" {
  type        = number
  description = "The desired number of Pods to run in parallel for a Job. Kubernetes will ensure that no more than this number of Pods are running at any given time."
}

variable "gcs_fuse_csi_driver_enabled" {
  type        = string
  description = "Set to true if the Cloud Storage FUSE CSI driver is enabled on your cluster"
}

variable "gcs_fuse_sidecar_cpu_limit" {
  type        = string
  description = "The maximum amount of CPU resource that the sidecar container can use"
}

variable "gcs_fuse_sidecar_memory_limit" {
  type        = string
  description = "The maximum amount of Memory resource that the sidecar container can use"
}

variable "gcs_fuse_sidecar_ephemeral_storage_limit" {
  type        = string
  description = "The maximum amount of Ephemeral Storage resource that the sidecar container can use"
}

variable "pscsi_driver_enabled" {
  type = string
}

variable "pscsi_sidecar_cpu_limit" {
  type = string
}

variable "pscsi_sidecar_memory_limit" {
  type = string
}

variable "dlio_container_cpu_limit" {
  type        = number
  description = "The maximum amount of CPU resource that the DLIO benchmark workload container can use"
}

variable "dlio_container_memory_limit" {
  type        = string
  description = "The maximum amount of Memory resource that the DLIO benchmark workload container can use"
}

variable "dlio_container_ephemeral_storage" {
  type        = string
  description = "The maximum amount of Ephemeral Storage resource that the DLIO benchmark workload container can use"
}

variable "dlio_data_mount_path" {
  type        = string
  description = "The path where your GCS bucket volume or other volume is mounted"
}

variable "dlio_benchmark_result" {
  type        = string
  description = "The path stores benchmark result reports"
}

// DLIO configurations, detailed explanation check
// https://github.com/argonne-lcf/dlio_benchmark
// https://argonne-lcf.github.io/dlio_benchmark/config.html
variable "dlio_generate_data" {
  type        = string
  description = "Set to true to generate dataset"
}

variable "dlio_number_of_processors" {
  type        = number
  description = "The number of processors used to run the task"
}

variable "dlio_model" {
  type        = string
  description = "Specifying the name of the model"
}

variable "dlio_record_length" {
  type        = number
  description = "Size of each sample"
}

variable "dlio_record_length_stdev" {
  type        = number
  description = "Standard deviation of the size of samples"
}

variable "dlio_record_length_resize" {
  type        = number
  description = "Resized sample size"
}

variable "dlio_number_of_files" {
  type        = number
  description = "Number of files for the training set"
}

variable "dlio_profiler" {
  type        = string
  description = "Specifying the profiler to use [none|iostat|tensorflow|pytorch]"
}

variable "dlio_iostat_devices" {
  type        = string
  description = "Specifying the devices to perform iostat tracing"
}

variable "dlio_batch_size" {
  type        = number
  description = "Batch size for training"
}

variable "dlio_train_epochs" {
  type        = number
  description = "Number of epochs to simulate"
}

variable "dlio_read_threads" {
  type        = number
  description = "Number of threads to load the data (for tensorflow and pytorch data loader)"
}
