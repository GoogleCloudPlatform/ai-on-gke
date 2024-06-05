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

locals {
  configsync_repository = module.configsync_repository
  git_repository        = replace(local.configsync_repository.html_url, "/https*:\\/\\//", "")
}

module "configsync_repository" {
  source = "../../../terraform/modules/github_repository"

  branches = {
    default = var.environment_name
    names   = ["main", var.environment_name]
  }
  description = "Google Cloud Config Sync repository"
  name        = var.configsync_repo_name
  owner       = var.github_org
  token       = var.github_token
}
