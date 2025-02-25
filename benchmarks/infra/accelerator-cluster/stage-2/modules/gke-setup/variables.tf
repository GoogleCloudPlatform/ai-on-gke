/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "credentials_config" {
  description = "Configure how Terraform authenticates to the cluster."
  type = object({
    fleet_host = optional(string)
    kubeconfig = optional(object({
      context = optional(string)
      path    = optional(string, "~/.kube/config")
    }))
  })
  nullable = false
  validation {
    condition = (
      (var.credentials_config.fleet_host != null) !=
      (var.credentials_config.kubeconfig != null)
    )
    error_message = "Exactly one of fleet host or kubeconfig must be set."
  }
}

variable "workload_identity_create" {
  description = "Setup Workload Identity configuration for newly created GKE cluster. Set to false to skip."
  type        = bool
  default     = true
}

variable "gcs_fuse_create" {
  description = "Setup GCS Fuse configuration for newly created GKE cluster. Set to false to skip."
  type        = bool
  default     = true
}

variable "nvidia_dcgm_create" {
  description = "Setup Nvidia DCGM configuration for newly created GKE cluster. Set to false to skip."
  type        = bool
  default     = true
}

variable "secret_create" {
  description = "Setup secret placeholder in Secret Manager, to be used to access llm models. Set to false to skip."
  type        = bool
  default     = false
}

variable "project_id" {
  description = "Project id of existing or created project."
  type        = string
}

variable "namespace" {
  description = "Namespace used for AI benchmark cluster resources."
  type        = string
  nullable    = false
  default     = "benchmark"
}

variable "namespace_create" {
  description = "Create Kubernetes namespace"
  type        = bool
  default     = true
}

variable "kubernetes_service_account" {
  description = "Name for the Kubernetes Service Account to be used for benchmark"
  type        = string
  nullable    = false
  default     = "benchmark-ksa"
}

variable "kubernetes_service_account_create" {
  description = "Create Kubernetes Service Account to be used for benchmark"
  type        = bool
  default     = true
}

variable "google_service_account" {
  description = "Name for the Google Service Account to be used for benchmark"
  type        = string
  nullable    = false
  default     = "benchmark-sa"
}

variable "google_service_account_create" {
  description = "Create Google service account to bind to a Kubernetes service account."
  type        = bool
  default     = true
}

variable "bucket_name" {
  description = "GCS bucket name"
  type        = string
  nullable    = false
}

variable "bucket_location" {
  description = "Location of GCS bucket"
  type        = string
  default     = "US"
}

variable "cluster_region" {
  description = "Cluster region"
  type        = string
  default     = "us-central1"
}

variable "output_bucket_name" {
  description = "Name of GCS bucket for test results"
  type        = string
}

variable "output_bucket_location" {
  description = "Location of GCS bucket for test results"
  type        = string
  default     = "US"
}

variable "benchmark_runner_kubernetes_service_account" {
  description = "Kubernetes Service Account to be used for Benchmarking Tool runner"
  type        = string
  default     = "locust-runner-ksa"
}

variable "benchmark_runner_google_service_account" {
  description = "Name for the Google Service Account to be used for Benchmarking Toolrunner"
  type        = string
  nullable    = false
  default     = "locust-runner-sa"
}

variable "secret_name" {
  description = "Secret name"
  type        = string
  default     = null
  nullable    = true
}

variable "secret_location" {
  description = "Location of secret"
  type        = string
  default     = null
  nullable    = true
}
