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

#######################################################
####    APPLICATIONS
#######################################################

provider "google" {
  project = var.project_id
}

provider "time" {}

data "google_client_config" "default" {}

data "google_project" "project" {
  project_id = var.project_id
}

## Enable Required GCP Project Services APIs
module "project-services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 14.5"

  project_id                  = var.project_id
  disable_services_on_destroy = false
  disable_dependent_services  = false
  activate_apis = flatten([
    "autoscaling.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "config.googleapis.com",
    "connectgateway.googleapis.com",
    "container.googleapis.com",
    "containerfilesystem.googleapis.com",
    "dns.googleapis.com",
    "gkehub.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "servicenetworking.googleapis.com",
    "serviceusage.googleapis.com",
    "sourcerepo.googleapis.com",
    "iap.googleapis.com"
  ])
}

module "infra" {
  source = "github.com/GoogleCloudPlatform/ai-on-gke/infrastructure"
  count  = var.create_cluster ? 1 : 0

  project_id                = var.project_id
  cluster_name              = var.cluster_name
  cluster_location          = var.cluster_location
  autopilot_cluster         = var.autopilot_cluster
  private_cluster           = var.private_cluster
  create_network            = true
  network_name              = var.network_name
  subnetwork_name           = var.subnetwork_name
  cpu_pools                 = var.cpu_pools
  enable_gpu                = var.enable_gpu
  gpu_pools                 = var.gpu_pools
  ray_addon_enabled         = true
  depends_on                = [module.project-services]
  kubernetes_version        = var.kubernetes_version
  subnetwork_private_access = true
}

data "google_container_cluster" "default" {
  count      = var.create_cluster ? 0 : 1
  name       = var.cluster_name
  location   = var.cluster_location
  depends_on = [module.project-services]
}

data "google_service_account" "gke_service_account" {
  account_id = module.infra[0].service_account
}

locals {
  endpoint              = var.create_cluster ? "https://${module.infra[0].endpoint}" : "https://${data.google_container_cluster.default[0].endpoint}"
  ca_certificate        = var.create_cluster ? base64decode(module.infra[0].ca_certificate) : base64decode(data.google_container_cluster.default[0].master_auth[0].cluster_ca_certificate)
  private_cluster       = var.create_cluster ? var.private_cluster : data.google_container_cluster.default[0].private_cluster_config.0.enable_private_endpoint
  enable_autopilot      = var.create_cluster ? var.autopilot_cluster : data.google_container_cluster.default[0].enable_autopilot
  helm_release_fullname = strcontains(var.helm_release_name, "flyte-binary") ? var.helm_release_name : "${var.helm_release_name}-flyte-binary"
  flyte_domains         = ["development", "staging", "production"]
}

module "gcs" {
  source      = "../../modules/gcs"
  count       = var.create_gcs_bucket ? 1 : 0
  project_id  = var.project_id
  bucket_name = var.gcs_bucket
}

# We assign the 'storage.admin' role to the service account to allow Flyte to get information about the GCS bucket
# Consider using a more restrictive role in production
resource "google_storage_bucket_iam_binding" "gke_service_account_bucket_object_admin" {
  bucket = var.gcs_bucket
  role   = "roles/storage.admin"
  members = [
    data.google_service_account.gke_service_account.member,
  ]
  depends_on = [module.gcs]
}

resource "google_project_iam_member" "workload_identity_sa_bindings" {
  project = "akvelon-gke-aieco"
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = data.google_service_account.gke_service_account.member
}

resource "google_service_account_iam_member" "main" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${data.google_service_account.gke_service_account.email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.kubernetes_namespace}/${local.helm_release_fullname}]"
}

resource "google_service_account_iam_member" "project-domains" {
  for_each = toset([
    for v in setproduct(var.flyte_projects, local.flyte_domains) : "${v[0]}-${v[1]}/default"
  ])

  service_account_id = "projects/${var.project_id}/serviceAccounts/${data.google_service_account.gke_service_account.email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.key}]"
}

resource "random_password" "csql_root_password" {
  length  = 16
  special = true
}
resource "random_password" "db_password" {
  length  = 16
  special = true
}

data "google_compute_network" "network" {
  name       = var.network_name
  depends_on = [module.infra]
}

resource "google_sql_database_instance" "flyte_storage" {
  project          = var.project_id
  name             = var.db_instance_name
  database_version = "POSTGRES_16"
  region           = var.cluster_location
  root_password    = random_password.csql_root_password.result
  settings {
    edition = "ENTERPRISE"
    tier    = var.db_tier
    ip_configuration {
      ipv4_enabled    = false
      private_network = data.google_compute_network.network.id
    }
  }
  depends_on = [
    module.infra
  ]

  # Allow deletion for demo purposes
  deletion_protection = false
}

resource "google_sql_database" "flyte_storage" {
  project  = var.project_id
  name     = var.database_name
  instance = google_sql_database_instance.flyte_storage.name
}

resource "google_sql_user" "users" {
  name     = var.cloudsql_user
  instance = google_sql_database_instance.flyte_storage.name
  password = random_password.db_password.result
}

resource "local_sensitive_file" "flyte_helm_values" {
  count = var.render_helm_values ? 1 : 0
  content = templatefile("${path.module}/values.yaml.tpl", {
    CLOUDSQL_USERNAME  = var.cloudsql_user,
    CLOUDSQL_PASSWORD  = random_password.db_password.result,
    CLOUDSQL_IP        = google_sql_database_instance.flyte_storage.private_ip_address,
    CLOUDSQL_DBNAME    = google_sql_database.flyte_storage.name,
    BUCKET_NAME        = var.gcs_bucket,
    PROJECT_ID         = var.project_id,
    FLYTE_IAM_SA_EMAIL = data.google_service_account.gke_service_account.email
  })
  filename = "${path.module}/flyte.yaml"
}
