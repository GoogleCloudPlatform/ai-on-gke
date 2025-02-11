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
  source = "../../../infrastructure"
  count  = var.create_cluster ? 1 : 0

  project_id         = var.project_id
  cluster_name       = local.cluster_name
  cluster_location   = var.cluster_location
  autopilot_cluster  = var.autopilot_cluster
  private_cluster    = var.private_cluster
  create_network     = false
  network_name       = "default"
  subnetwork_name    = "default"
  cpu_pools          = var.cpu_pools
  enable_gpu         = var.enable_gpu
  gpu_pools          = var.gpu_pools
  ray_addon_enabled  = true
  depends_on         = [module.project-services]
  kubernetes_version = var.kubernetes_version
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
  endpoint                          = var.create_cluster ? "https://${module.infra[0].endpoint}" : "https://${data.google_container_cluster.default[0].endpoint}"
  ca_certificate                    = var.create_cluster ? base64decode(module.infra[0].ca_certificate) : base64decode(data.google_container_cluster.default[0].master_auth[0].cluster_ca_certificate)
  private_cluster                   = var.create_cluster ? var.private_cluster : data.google_container_cluster.default[0].private_cluster_config.0.enable_private_endpoint
  cluster_membership_id             = var.cluster_membership_id == "" ? local.cluster_name : var.cluster_membership_id
  enable_autopilot                  = var.create_cluster ? var.autopilot_cluster : data.google_container_cluster.default[0].enable_autopilot
  enable_tpu                        = var.create_cluster ? var.enable_tpu : data.google_container_cluster.default[0].enable_tpu
  host                              = local.private_cluster ? "https://connectgateway.googleapis.com/v1/projects/${data.google_project.project.number}/locations/${var.cluster_location}/gkeMemberships/${local.cluster_membership_id}" : local.endpoint
  kubernetes_namespace              = var.goog_cm_deployment_name != "" ? "${var.goog_cm_deployment_name}-${var.kubernetes_namespace}" : var.kubernetes_namespace
  workload_identity_service_account = var.goog_cm_deployment_name != "" ? "${var.goog_cm_deployment_name}-${var.workload_identity_service_account}" : var.workload_identity_service_account
  cluster_name                      = var.goog_cm_deployment_name != "" ? "${var.goog_cm_deployment_name}-${var.cluster_name}" : var.cluster_name
}

module "gcs" {
  source      = "../../../modules/gcs"
  count       = var.create_gcs_bucket ? 1 : 0
  project_id  = var.project_id
  bucket_name = var.gcs_bucket
}

resource "google_storage_bucket_iam_binding" "allow_gke_to_bucket" {
  bucket = var.gcs_bucket
  role   = "roles/storage.admin"
  members = [
    data.google_service_account.gke_service_account.member,
  ]
}

module "skypilot-workload-identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  name                = "skypilot-service-account"
  namespace           = "default"
  project_id          = var.project_id
  roles               = ["roles/storage.admin", "roles/compute.admin"]
  cluster_name        = module.infra[0].cluster_name
  location            = var.cluster_location
  use_existing_gcp_sa = true
  gcp_sa_name         = data.google_service_account.gke_service_account.email
  use_existing_k8s_sa = true
  annotate_k8s_sa     = false
}
