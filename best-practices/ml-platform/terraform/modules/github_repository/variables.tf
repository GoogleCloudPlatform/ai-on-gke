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

variable "auto_init" {
  default     = true
  description = "Whether to produce an initial commit in the repository."
  type        = bool
}

variable "allow_merge_commit" {
  default     = false
  description = "Whether merge commits are allowed in the repository."
  type        = bool
}

variable "allow_rebase_merge" {
  default     = true
  description = "Whether rebase merges are allowed in the repository."
  type        = bool
}

variable "allow_squash_merge" {
  default     = false
  description = "Whether squash merges are allowed in the repository."
  type        = bool
}

variable "branches" {
  default = {
    default = "main"
    names   = ["main"]
  }
  description = "List of branches to create in the repository."
  type = object({
    default = string
    names   = list(string)
  })

  validation {
    condition     = contains(var.branches.names, var.branches.default)
    error_message = "'branches.default' must be in 'branches.names'"
  }
}

variable "delete_branch_on_merge" {
  default     = false
  description = "Whether to automatically delete the head branch after a pull request is merged."
  type        = bool
}

variable "description" {
  default     = null
  description = "A description of the repository."
  type        = string
}

variable "has_issues" {
  default     = false
  description = "Whether to enable the GitHub Issues features on the repository."
  type        = string
}

variable "has_projects" {
  default     = false
  description = "Whether to enable the GitHub Projects features on the repository."
  type        = string
}

variable "has_wiki" {
  default     = false
  description = "Whether to enable the GitHub Wiki features on the repository."
  type        = string
}

variable "owner" {
  description = "The GitHub organization or individual user account the repository will be created in."
  type        = string
}

variable "name" {
  description = "The name of the repository."
  type        = string
}

variable "token" {
  description = "GitHub OAuth / Personal Access Token."
  sensitive   = true
  type        = string
}

variable "visibility" {
  default     = "private"
  description = "The visibility of the repository."
  type        = string

  validation {
    condition     = contains(["internal", "private", "public"], var.visibility)
    error_message = "'visibility' must be 'internal', 'private', or'public'"
  }
}

variable "vulnerability_alerts" {
  default     = true
  description = "Whether to enable vulnerability alerts for vulnerable dependencies on the repository."
  type        = bool
}