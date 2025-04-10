/**
  * Copyright 2023 Google LLC
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

variable "goog_cm_deployment_name" {
  description = "The name of the deployment and VM instance."
  type        = string
}

variable "authorized_cidr" {
  description = "Toolkit deployment variable: authorized_cidr"
  type        = string
  default     = "0.0.0.0/0"
}

variable "reservation" {
  description = "Toolkit deployment variable: reservation"
  type        = string
}

variable "reservation_block" {
  description = "Toolkit deployment variable: reservation_block"
  type        = string
}

variable "labels" {
  description = "Toolkit deployment variable: labels"
  type        = any
  default     = {}
}

variable "project_id" {
  description = "Toolkit deployment variable: project_id"
  type        = string
  default     = ""
}

variable "a3_mega_zone" {
  description = "Toolkit deployment variable: a3_mega_zone"
  type        = string
}

variable "a3_ultra_zone" {
  description = "Toolkit deployment variable: a3_ultra_zone"
  type        = string
}

variable "node_count_gke" {
  description = "Toolkit deployment variable: node_count_gke"
  type        = number
}

variable "node_count_gke_nccl" {
  description = "Toolkit deployment variable: node_count_gke_nccl"
  type        = number
}

variable "node_count_gke_ray" {
  description = "Toolkit deployment variable: node_count_ray"
  type        = number
}

variable "node_count_llama_3_7b" {
  description = "Toolkit deployment variable: node_count_llama_3_7b"
  type        = number
}

variable "node_count_nemo" {
  description = "Toolkit deployment variable: node_count_nemo"
  type        = number
}

variable "node_count_maxtext" {
  description = "Toolkit deployment variable: node_count_maxtext"
  type        = number
}

variable "placement_policy_name" {
  description = "Toolkit deployment variable: placement_policy_name"
  type        = string
}

variable "a3mega_recipe" {
  description = "Toolkit deployment variable: a3mega_recipe"
  type        = string
}

variable "a3ultra_recipe" {
  description = "Toolkit deployment variable: a3ultra_recipe"
  type        = string
}

variable "gpu_type" {
  description = "Toolkit deployment variable: gpu_type"
  type        = string
} 

variable "a3_ultra_consumption_model" {
  description = "Toolkit deployment variable: a3_ultra_consumption_model"
  type        = string
}

variable "a3_mega_consumption_model" {
  description = "Toolkit deployment variable: a3_mega_consumption_model"
  type        = string
}

locals {
  placement_policy_valid = var.gpu_type != "A3 Mega" || length(var.placement_policy_name) > 0
  a3_consumption_model_check = length(var.a3_ultra_consumption_model) > 0 || length(var.a3_mega_consumption_model) > 0
  recipe = {
    "A3 Mega" = var.a3mega_recipe
    "A3 Ultra" = var.a3ultra_recipe
  }[var.gpu_type]
  recipes_not_empty = length(local.recipe) > 0
  reservation_valid = !(local.recipe != "gke") || length(var.reservation) > 0
}

resource "null_resource" "input_validation" {
  count = 1

  lifecycle {
    precondition {
      condition     = local.placement_policy_valid
      error_message = "placement_policy_name must be provided when gpu_type is A3 Mega."
    }
    precondition {
      condition     = local.a3_consumption_model_check
      error_message = "Either a3_ultra_consumption_model or a3_mega_consumption_model must be specified. They cannot both be empty."
    }
    precondition {
      condition     = local.recipes_not_empty
      error_message = "Must input one recipe."
    }
    # precondition {
    #   condition     = local.reservation_valid
    #   error_message = "The 'reservation' variable must not be empty when recipe is not 'gke'."
    # }
  }
}
