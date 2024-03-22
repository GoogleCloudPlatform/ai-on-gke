# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "billing_account" {
  default     = ""
  description = "GCP billing account"
  type        = string
}

variable "env" {
  default     = "dev"
  description = "Name of the environments"
  type        = string
}

variable "folder_id" {
  default     = ""
  description = "Folder id where the GCP projects will be created"
  type        = string
}

variable "org_id" {
  default     = ""
  type        = string
  description = "The GCP orig id"
}

variable "project_id" {
  default     = ""
  description = "Google Cloud project ID"
  type        = string
}

variable "project_name" {
  default     = ""
  description = "GCP project name"
  type        = string
}
