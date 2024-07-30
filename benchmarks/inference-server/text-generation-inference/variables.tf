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
  description = "Namespace used for TGI resources."
  type        = string
  nullable    = false
  default     = "default"
}

variable "model_id" {
  description = "Model used for inference."
  type        = string
  nullable    = false
  default     = "tiiuae/falcon-7b"
}

variable "gpu_count" {
  description = "Parallelism based on number of gpus."
  type        = number
  nullable    = false
  default     = 1
  validation {
    condition     = var.gpu_count == 1 || var.gpu_count == 2 || var.gpu_count == 4 || var.gpu_count == 8
    error_message = "Huggingface TGI server supports gpu_count equal to one of 1, 2, 4, or 8."
  }
}

variable "max_concurrent_requests" {
  description = "Max concurrent requests allowed for TGI to handle at once. TGI will drop all requests once it hits this max-concurrent-requests limit."
  type        = number
  nullable    = false
  # TODO: default is same as tgi's default for now, update with reasonable number.
  default = 128
  validation {
    condition     = var.max_concurrent_requests > 0
    error_message = "Max conccurent requests must be greater than 0."
  }
}

variable "quantization" {
  description = "Quantization used for the model. Can be one of the quantization options mentioned in https://huggingface.co/docs/text-generation-inference/en/basic_tutorials/launcher#quantize. `eetq` and `bitsandbytes` can be applied to any models whereas others might require the use of quantized checkpoints."
  type        = string
  nullable    = true
  default     = ""
}

variable "ksa" {
  description = "Kubernetes Service Account used for workload."
  type        = string
  nullable    = false
  default     = "default"
}

variable "templates_path" {
  description = "Path where manifest templates will be read from. Set to null to use the default manifests"
  type        = string
  default     = null
}

variable "secret_templates_path" {
  description = "Path where secret configuration manifest templates will be read from. Set to null to use the default manifests"
  type        = string
  default     = null
}

variable "hugging_face_secret" {
  description = "Secret id in Secret Manager"
  type        = string
  nullable    = true
  default     = null
}

variable "hugging_face_secret_version" {
  description = "Secret version in Secret Manager"
  type        = string
  nullable    = true
  default     = null
}

variable "hpa_type" {
  description = "How the TGI workload should be scaled."
  type        = string
  default     = null
  nullable    = true
  validation {
    condition     = var.hpa_type == null ? true : length(regexall("cpu|tgi_.*|DCGM_.*", var.hpa_type)) > 0
    error_message = "Allows values for hpa_type are {null, \"cpu\", TGI metrics (e.g., \"tgi_queue_size\", \"tgi_batch_current_size\") or DCGM metrics (e.g., \"DCGM_FI_DEV_MEM_COPY_UTIL\") }"
  }
}

variable "hpa_min_replicas" {
  description = "Minimum number of HPA replicas."
  type        = number
  default     = 1
  nullable    = false
}

variable "hpa_max_replicas" {
  description = "Maximum number of HPA replicas."
  type        = number
  default     = 5
  nullable    = false
}

# TODO: combine hpa variables into a single object (so that they can be
# validated together)
variable "hpa_averagevalue_target" {
  description = "AverageValue target for the `hpa_type` metric. Must be set if `hpa_type` is not null."
  type        = number
  default     = null
  nullable    = true
}

variable "project_id" {
  description = "Project id of existing or created project."
  type        = string
}
