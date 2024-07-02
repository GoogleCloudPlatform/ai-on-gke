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

variable "branches" {
  default = {
    default = "main"
    names   = ["main"]
  }
  description = "List of branches to create in the repository."
  type = object({
    default = string
    names   = list(string),
  })

  validation {
    condition     = contains(var.branches.names, var.branches.default)
    error_message = "'branches.default' must be in 'branches.names'"
  }
}

variable "description" {
  default     = null
  description = "A description of the project."
  type        = string
}

variable "group_full_path" {
  description = "The full path of the group."
  type        = string
}

variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "token" {
  description = "The OAuth2 Token, Project, Group, Personal Access Token or CI Job Token used to connect to GitLab."
  sensitive   = true
  type        = string
}

variable "visibility_level" {
  default     = "private"
  description = "The visibility level of the project."
  type        = string

  validation {
    condition     = contains(["internal", "private", "public"], var.visibility_level)
    error_message = "'visibility_level' must be 'internal', 'private', or'public'"
  }
}
