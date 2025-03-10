# Copyright 2024 Google LLC
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

data "google_compute_network" "database" {
  project = var.project_id
  name    = var.db_network
}

resource "google_compute_global_address" "google_managed_services_default" {
  project       = var.project_id
  name          = "google-managed-services-default"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = data.google_compute_network.database.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = data.google_compute_network.database.id
  service                 = "services/servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.google_managed_services_default.name]
}

resource "random_password" "db_password" {
  length  = 16
  special = false
}

resource "google_sql_database_instance" "langchain_storage" {
  project          = var.project_id
  name             = var.db_instance_name
  database_version = "POSTGRES_16"
  region           = var.db_region
  root_password    = random_password.db_password.result
  settings {
    edition = "ENTERPRISE"
    tier = var.db_tier
    ip_configuration {
      ipv4_enabled    = false
      private_network = data.google_compute_network.database.id
    }
  }
  depends_on = [
    google_service_networking_connection.private_vpc_connection
  ]

  # Allow deletion for demo purposes
  deletion_protection = false
}

resource "google_sql_database" "langchain_storage" {
  project  = var.project_id
  name     = var.db_name
  instance = google_sql_database_instance.langchain_storage.name
}