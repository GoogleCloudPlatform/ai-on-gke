# Copyright 2025 Google LLC
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

resource "random_password" "pwd" {
  length  = 16
  special = false
}

locals {
  metaflow_database_name     = "metaflow-tutorial"
  metaflow_cloudsql_instance = var.metaflow_cloudsql_instance != "" ? var.metaflow_cloudsql_instance : var.default_resource_name
}

module "cloudsql" {

  source              = "terraform-google-modules/sql-db/google//modules/postgresql"
  project_id          = var.project_id
  version             = "20.0.0"
  name                = local.metaflow_cloudsql_instance
  database_version    = "POSTGRES_15"
  region              = var.metaflow_cloudsql_instance_region
  deletion_protection = false
  tier                = "db-f1-micro"

  database_deletion_policy = "ABANDON"
  user_deletion_policy     = "ABANDON"

  ip_configuration = {
    # Disable public IP
    ipv4_enabled                                  = false
    private_network                               = "projects/${var.project_id}/global/networks/${local.network_name}"
    enable_private_path_for_google_cloud_services = true
  }

  // By default, all users will be permitted to connect only via the
  // Cloud SQL proxy.
  // Create an additional user here for connection from the workload.
  additional_users = [
    {
      name            = var.metaflow_db_user
      password        = random_password.pwd.result
      host            = "localhost"
      type            = "BUILT_IN"
      random_password = false
    },
  ]

  additional_databases = [
    {
      name      = local.metaflow_database_name
      charset   = "UTF8"
      collation = "en_US.UTF8"
    },
  ]
  depends_on = [module.custom_network]
}

resource "kubernetes_secret" "secret" {
  provider = kubernetes.metaflow
  metadata {
    name      = "db-secret"
    namespace = var.metaflow_kubernetes_namespace
  }

  data = {
    username = var.metaflow_db_user
    password = random_password.pwd.result
    database = local.metaflow_database_name
  }

  type       = "kubernetes.io/basic-auth"
  depends_on = [module.gke_cluster]
}
