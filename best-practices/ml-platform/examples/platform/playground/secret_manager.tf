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
  git_config_secret_name = "${var.environment_name}-git-config"
}

resource "google_secret_manager_secret" "git_config" {
  project   = google_project_service.secretmanager_googleapis_com.project
  secret_id = local.git_config_secret_name

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "git_config" {
  secret = google_secret_manager_secret.git_config.id

  secret_data = jsonencode({
    "namespace"  = var.git_namespace,
    "token"      = var.git_token,
    "user_email" = var.git_user_email,
    "user_name"  = var.git_user_name,
  })
}
