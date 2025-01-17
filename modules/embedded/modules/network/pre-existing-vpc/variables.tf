/**
 * Copyright 2022 Google LLC
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

variable "project_id" {
  description = "Project in which the HPC deployment will be created"
  type        = string
}

variable "network_name" {
  description = "Name of the existing VPC network"
  type        = string
  default     = "default"
}

variable "subnetwork_name" {
  description = "Name of the pre-existing VPC subnetwork; defaults to var.network_name if set to null."
  type        = string
  default     = null
}

variable "region" {
  description = "Region in which to search for primary subnetwork"
  type        = string
}
