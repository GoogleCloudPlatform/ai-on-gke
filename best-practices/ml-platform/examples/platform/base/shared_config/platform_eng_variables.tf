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

variable "platform_eng_configconnector_operator_version" {
  default     = "1.119.0"
  description = "Version of the config connector operator to install"
  type        = string
}

variable "platform_eng_git_namespace" {
  description = "The namespace of the git repository"
  type        = string
}

variable "platform_eng_git_repository_name" {
  default     = "mlp-platform-eng-configsync"
  description = "The name of the git repository"
  type        = string
}

variable "platform_eng_git_token" {
  description = "The token to use for git"
  type        = string
}

variable "platform_eng_git_user_email" {
  description = "The user email to configure for git"
  type        = string
}

variable "platform_eng_git_user_name" {
  description = "The user name to configure for git"
  type        = string
}

variable "platform_eng_project_id" {
  description = "Project ID of the Platform Engineering project"
  type        = string
}

variable "platform_eng_region" {
  default     = "us-central1"
  description = "Default region for the Platform Engineering project"
  type        = string
}
