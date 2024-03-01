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

variable "namespace" {
  description = "Namespace used for Nvidia DCGM resources."
  type        = string
  nullable    = false
  default     = "default"
}

variable "image_path" {
  description = "Image Path stored in Artifact Registry"
  type        = string
  nullable    = false
}

variable "model_id" {
  description = "Model used for inference."
  type        = string
  nullable    = false
  default     = "meta-llama/Llama-2-7b-chat-hf"
}

variable "gpu_count" {
  description = "Parallelism based on number of gpus."
  type        = number
  nullable    = false
  default     = 1
}

variable "ksa" {
  description = "Kubernetes Service Account used for workload."
  type        = string
  nullable    = false
  default     = "default"
}

variable "huggingface-secret" {
  description = "name of the kubectl huggingface secret token"
  type        = string
  nullable    = true
  default     = "huggingface-secret"
}

variable "template_path" {
  description = "Path where manifest templates will be read from."
  type        = string
  nullable    = false
}

