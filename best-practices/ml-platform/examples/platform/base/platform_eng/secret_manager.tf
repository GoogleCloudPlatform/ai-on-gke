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

resource "google_secret_manager_secret" "platform_eng_git_token" {
  project   = google_project_service.platform_eng_secretmanager_googleapis_com.project
  secret_id = "platform-eng-git-token"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "platform_eng_git_token" {
  secret      = google_secret_manager_secret.platform_eng_git_token.id
  secret_data = var.platform_eng_git_token
}

resource "google_secret_manager_secret" "backstage_cloud_sql_admin_password" {
  project   = google_project_service.platform_eng_secretmanager_googleapis_com.project
  secret_id = "backstage_cloud_sql_admin_user"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "cloud_sql_admin_password" {
  secret      = google_secret_manager_secret.backstage_cloud_sql_admin_password.id
  secret_data = random_password.backstage_cloud_sql_admin_password.result
}
