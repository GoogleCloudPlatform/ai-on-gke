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

variable "lookup_state_bucket" {
  description = "GCS bucket to look up TF state from previous steps."
  type        = string
  default     = "YOUR_STATE_BUCKET"
}

variable "configsync_repo_name" {
  type        = string
  description = "Name of the GitHub repo that will be synced to the cluster with Config sync."
  default     = "config-sync-repo"
}

variable "github_user" {
  description = "GitHub user name."
  type        = string
  default     = "YOUR_GIT_USER"
}

variable "github_email" {
  description = "GitHub user email."
  type        = string
  default     = "YOUR_GIT_USER_EMAIL"
}

variable "github_org" {
  type        = string
  description = "GitHub org."
  default     = "YOUR_GIT_ORG"
}

variable "github_token" {
  type        = string
  description = "GitHub token. It is a token with write permissions as it will create a repo in the GitHub org."
}
