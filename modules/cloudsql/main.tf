# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Enabled the SQLAdmin service 
resource "google_project_service" "project_service" {
  project = var.project_id
  service = "sqladmin.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_sql_database_instance" "main" {
  name             = "pgvector-instance"
  database_version = "POSTGRES_15"
  region           = var.region
  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = "db-f1-micro"
  }

  deletion_protection = false
}

resource "google_sql_database" "database" {
  name     = "pgvector-database"
  instance = "pgvector-instance"

  depends_on = [ google_sql_database_instance.main ]
}

resource "random_password" "pwd" {
  length  = 16
  special = false
}

resource "google_sql_user" "cloudsql_user" {
  name     = var.db_user
  instance = google_sql_database_instance.main.name
  password = random_password.pwd.result
}

resource "kubernetes_secret" "secret" {
  metadata {
    name = "db-secret"
    namespace = var.namespace
  }

  data = {
    username = var.db_user
    password = random_password.pwd.result
    database = "pgvector-database"
  }

  type = "kubernetes.io/basic-auth"
}
