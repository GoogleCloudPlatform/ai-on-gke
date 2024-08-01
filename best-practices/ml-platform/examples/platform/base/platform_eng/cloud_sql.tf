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

resource "google_sql_database_instance" "backstage" {
  depends_on = [google_project_service.platform_eng_sqladmin_googleapis_com]

  database_version    = "POSTGRES_15"
  deletion_protection = false
  name                = "backstage"
  project             = data.google_project.platform_eng.project_id
  region              = var.platform_eng_region

  settings {
    availability_type = "REGIONAL"
    tier              = "db-custom-4-16384"
  }
}

resource "random_password" "backstage_cloud_sql_admin_password" {
  length           = 16
  special          = true
  override_special = "!%*()-_{}<>"
}

resource "google_sql_user" "backstage_cloud_sql_admin_user" {
  instance = google_sql_database_instance.backstage.name
  name     = "admin"
  password = random_password.backstage_cloud_sql_admin_password.result
  project  = google_sql_database_instance.backstage.project
}
