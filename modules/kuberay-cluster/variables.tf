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
  default     = "ray-cluster"
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

variable "additional_labels" {
  // string is used instead of map(string) since blueprint metadata does not support maps.
  type        = string
  description = "Additional labels to add to Kubernetes resources."
  default     = "created-by=ai-on-gke,ai.gke.io=ray"
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

# Note: Same namespace and gmp-system ingress are hardcoded into the allowlist.
#
# This is a list of maps of Kubernetes namespaces, by name, to
# a Ray cluster's job submission API and Dashboard.
#
# Example:
# network_policy_allow_namespaces = ["onespace", "twospace", "redspace", "bluespace"]
#
variable "network_policy_allow_namespaces" {
  description = "Namespaces allowed to access this kuberay cluster"
  type        = list(string)
  default     = [""]
}

# This is a list of CIDR ranges allowed to access a Ray cluster's job submission API and Dashboard.
#
# Example:
# network_policy_allow_cidr = "10.0.0.0/8"
#
variable "network_policy_allow_cidr" {
  description = "CIDR range allowed to access this kuberay cluster"
  type        = string
  default     = ""
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

# -----------------IAP----------------------------
variable "create_brand" {
  type        = bool
  description = "Create Brand OAuth Screen"
  default     = false
}

variable "add_auth" {
  type        = bool
  description = "Enable iap authentication on frontend"
  default     = false
}

variable "k8s_ingress_name" {
  type    = string
  default = "ray-dashboard-ingress"
}

variable "k8s_managed_cert_name" {
  type        = string
  description = "Name for frontend managed certificate"
  default     = "ray-dashboard-managed-cert"
}

variable "k8s_iap_secret_name" {
  type    = string
  default = "ray-dashboard-secret"
}

variable "k8s_backend_config_name" {
  type        = string
  description = "Name of the Backend Config on GCP"
  default     = "ray-dashboard-iap-config"
}

variable "k8s_backend_service_port" {
  type        = number
  description = "Name of the K8s Backend Service Port"
  default     = 8265
}

variable "domain" {
  type        = string
  description = "Provide domain for ingress resource and ssl certificate."
  default     = ""
}

variable "support_email" {
  type        = string
  description = "Email for users to contact with questions about their consent"
  default     = "<email>"
}

variable "client_id" {
  type        = string
  description = "Client ID used for enabling IAP"
  default     = ""
}

variable "client_secret" {
  type        = string
  description = "Client secret used for enabling IAP"
  default     = ""
  sensitive   = false
}

variable "members_allowlist" {
  type    = list(string)
  default = []
}

variable "use_custom_image" {
  type        = bool
  description = "If running RAG, set this var to true to use custome image with pre-installed lib"
  default     = false
}