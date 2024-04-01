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
  description = "Namespace used for model and benchmarking deployments."
  type        = string
  nullable    = false
  default     = "default"
}

variable "project_id" {
  description = "Project id of existing or created project."
  type        = string
  nullable    = false
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

variable "artifact_registry" {
  description = "Artifact registry for storing Locust container."
  type        = string
  default     = null
}

variable "num_locust_workers" {
  description = "Number of locust worker pods to deploy."
  type        = number
  default     = 1
}

variable "inference_server_service" {
  description = "Inference server service"
  type        = string
  nullable    = false
}

variable "inference_server_framework" {
  description = "Benchmark server configuration for inference server framework. Can be one of: vllm, tgi, tensorrt_llm_triton, sax"
  type        = string
  nullable    = false
  default     = "tgi"
  validation {
    condition     = var.inference_server_framework == "vllm" || var.inference_server_framework == "tgi" || var.inference_server_framework == "tensorrt_llm_triton" || var.inference_server_framework == "sax"
    error_message = "The inference_server_framework must be one of: vllm, tgi, tensorrt_llm_triton, sax."
  }
}

variable "best_of" {
  description = "Benchmark server configuration for best of."
  type        = number
  default     = 1
}

variable "gcs_path" {
  description = "Benchmark server configuration for gcs_path for downloading prompts."
  type        = string
  nullable    = false
}

variable "max_num_prompts" {
  description = "Benchmark server configuration for max number of prompts."
  type        = number
  default     = 1000
  validation {
    condition     = var.max_num_prompts > 0
    error_message = "The max_num_prompts value must be greater than 0."
  }
}

variable "max_output_len" {
  description = "Benchmark server configuration for max output length."
  type        = number
  default     = 256
  validation {
    condition     = var.max_output_len > 4
    error_message = "The max_output_len value must be greater than 4. TGI framework throws an error for too short of sequences."
  }
}

variable "max_prompt_len" {
  description = "Benchmark server configuration for max prompt length."
  type        = number
  default     = 256
  validation {
    condition     = var.max_prompt_len > 4
    error_message = "The max_prompt_len value must be greater than 4. TGI framework throws an error for too short of sequences."
  }
}

variable "sax_model" {
  description = "Benchmark server configuration for sax model. Only required if framework is sax."
  type        = string
  default     = ""
}

variable "tokenizer" {
  description = "Benchmark server configuration for tokenizer."
  type        = string
  nullable    = false
  default     = "tiiuae/falcon-7b"
}

variable "use_beam_search" {
  description = "Benchmark server configuration for use beam search."
  type        = bool
  default     = false
}

variable "output_bucket" {
  description = "Bucket name for storing results"
  type        = string
}

variable "locust_runner_kubernetes_service_account" {
  description = "Kubernetes Service Account to be used for Locust runner tool"
  type        = string
  default     = "sample-runner-ksa"
}

variable "runner_endpoint_ip" {
  description = "External IP assigned to Locust Runner"
  type        = string
  nullable    = true
  default     = null
}

variable "test_duration" {
  description = "Duration of automated test in seconds"
  type        = number
  default     = 120
}

variable "test_users" {
  description = "Users parameter for Locust"
  type        = number
  default     = 1
}

variable "test_rate" {
  description = "Rate parameter for Locust"
  type        = number
  default     = 5
}

variable "run_test_automatically" {
  description = "Run the test after deployment"
  type        = bool
  default     = false
}

variable "huggingface_secret" {
  description = "name of the kubectl huggingface secret token"
  type        = string
  nullable    = true
  default     = "huggingface-secret"
}
