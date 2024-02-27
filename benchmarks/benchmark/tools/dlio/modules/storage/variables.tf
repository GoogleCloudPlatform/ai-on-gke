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

variable "gcs_bucket" {
  type        = string
  description = "GCS Bucket name"
}

// pv, pvc
variable "pv_name" {
  type        = string
  description = "Name of the PersistentVolume used for DLIO dataset"
}

variable "pvc_name" {
  type        = string
  description = "Name of the PersistentVolumeClaim used for DLIO dataset"
}

// gcsfuse cache configurations
variable "gcsfuse_stat_cache_capacity" {
  type        = string
  description = "Size of the Cloud Storage Fuse stat cache"
}

variable "gcsfuse_stat_cache_ttl" {
  type        = string
  description = "Specifies how long Cloud Storage FUSE caches stat entries"
}

variable "gcsfuse_type_cache_ttl" {
  type        = string
  description = "Specifies how long Cloud Storage FUSE caches the mapping of objects in Cloud Storage to their corresponding type, such as files or directories"
}