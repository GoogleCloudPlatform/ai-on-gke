# Copyright 2023 Google LLC
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

variable "project_id" {
  type        = string
  description = "GCP project id"
}

variable "name" {
  type        = string
  description = "Name of the ray cluster"
  default     = "example-cluster"
}

variable "db_region" {
  type        = string
  description = "Cloud SQL instance region"
  default     = "us-central1"
}

variable "cloudsql_instance_name" {
  type        = string
  description = "Cloud SQL instance name"
  default     = "pgvector-instance"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace where resources are deployed"
  default     = "ray-system"
}

variable "enable_tpu" {
  type        = bool
  description = "Set to true to request TPUs in Ray cluster (not supported on GKE Autopilot)"
  default     = false
}

variable "enable_gpu" {
  type        = bool
  description = "Set to true to request GPUs in Ray cluster"
  default     = false
}

variable "autopilot_cluster" {
  type = bool
}

variable "google_service_account" {
  type        = string
  description = "Google service account name"
  default     = "kuberay-gcp-sa"
}

variable "gcs_bucket" {
  type        = string
  description = "GCS Bucket name"
}

variable "grafana_host" {
  type = string
}

# Commenting out underutilized, nested variables because they're harder to
# strip from the YAML encoding. Add these back if we can easily strip out
# the null values.
variable "security_context" {
  description = "Kubernetes security context to set on all ray cluster pods"
  type = object({
    allowPrivilegeEscalation = optional(bool)
    capabilities = optional(object({
      # Not typically used
      # add  = optional(list(string))
      drop = optional(list(string))
    }))
    privileged             = optional(bool)
    procMount              = optional(string)
    readOnlyRootFilesystem = optional(bool)
    runAsGroup             = optional(number)
    runAsNonRoot           = optional(bool)
    runAsUser              = optional(number)
    seLinuxOptions = optional(object({
      level = optional(string)
      role  = optional(string)
      type  = optional(string)
      user  = optional(string)
    }))
    seccompProfile = optional(object({
      # Not typically used
      # localhostProfile = optional(string)
      type = optional(string)
    }))
    windowsOptions = optional(object({
      gmsaCredentialSpec    = optional(string)
      gmsaCredentiaSpecName = optional(string)
      hostProcess           = bool
      runAsUserName         = string
    }))
  })

  default = {
    allowPrivilegeEscalation = false
    capabilities = {
      drop = ["ALL"]
    }
    # GKE will automatically mount GPUs and TPUs into unprivileged pods
    privileged         = false
    readOnlyFileSystem = true
    runAsNonRoot       = true
    seccompProfile = {
      type = "RuntimeDefault"
    }
  }
}

# Note: By default, intra-namespace ingress is allowed to let the cluster talk to itself
#
# This is a list of maps of arbitrary key/value pairs of namespace labels allowed to access
# a Ray cluster's job submission API and Dashboard. These labels act as ORs, not ANDs.
#
# Example:
# network_policy_allow_namespaces_by_label = [{user: "jane"}, {"kubernetes.io/metadata.name": "janespace"}]
#
variable "network_policy_allow_namespaces_by_label" {
  description = "Namespaces allowed to access this kuberay cluster"
  type        = list(map(string))
  default     = []
}

# This is a list of maps of arbitrary key/value pairs of pod labels allowed to access
# a Ray cluster's job submission API and Dashboard. These labels act as ORs, not ANDs.
#
# Example:
# network_policy_allow_pods_by_label = [{role: "frontend"}, {"app": "jupyter"}]
#
variable "network_policy_allow_pods_by_label" {
  description = "Pods allowed to access this kuberay cluster"
  type        = list(map(string))
  default     = []
}

# This is a list of CIDR ranges allowed to access a Ray cluster's job submission API and Dashboard.
#
# Example:
# network_policy_allow_ips = ['10.0.0.0/8', '192.168.0.0/24']
#
variable "network_policy_allow_ips" {
  description = "CIDR ranges allowed to access this kuberay cluster"
  type        = list(string)
  default     = []
}

variable "db_secret_name" {
  type        = string
  description = "CloudSQL user credentials"
  default     = "empty-secret"
}

variable "disable_network_policy" {
  description = "Set to true to remove network policy / firewalls from your Ray clusters. Not recommended."
  type        = bool
  default     = false
}

# These default resource quotas are set intentionally high as an example that won't be limiting for most clusters.
# Consult https://kubernetes.io/docs/concepts/policy/resource-quotas/ for additional quotas that may be set.
variable "resource_quotas" {
  description = "Kubernetes ResourceQuota object to attach to the Ray cluster's namespace"
  type        = map(string)
  default = {
    cpu                       = "1000"
    memory                    = "10Ti"
    "requests.nvidia.com/gpu" = "100"
    "requests.google.com/tpu" = "100"
  }
}

variable "disable_resource_quotas" {
  description = "Set to true to remove resource quotas from your Ray clusters. Not recommended"
  type        = bool
  default     = false
}
