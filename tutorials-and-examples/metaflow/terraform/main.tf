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


terraform {

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

data "google_client_config" "default" {}

data "google_project" "project" {
  project_id = var.project_id
}
locals {
  cluster_name = var.cluster_name != "" ? var.cluster_name : var.default_resource_name
}

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

module "gke_cluster" {
  source            = "../../../infrastructure"
  project_id        = var.project_id
  cluster_name      = local.cluster_name
  cluster_location  = var.cluster_location
  autopilot_cluster = var.autopilot_cluster
  private_cluster   = var.private_cluster
  create_network    = false
  network_name      = local.network_name
  subnetwork_name   = local.subnetwork_name
  subnetwork_region = var.subnetwork_region
  subnetwork_cidr   = var.subnetwork_cidr
  enable_gpu        = true
  gpu_pools = [
    {
      name               = "gpu-pool-a100"
      machine_type       = "a2-highgpu-1g"
      node_locations     = "us-central1-a"
      autoscaling        = true
      min_count          = 1
      max_count          = 3
      disk_size_gb       = 100
      disk_type          = "pd-balanced"
      enable_gcfs        = true
      logging_variant    = "DEFAULT"
      accelerator_count  = 1
      accelerator_type   = "nvidia-tesla-a100"
      gpu_driver_version = "DEFAULT"
    }
  ]
  ray_addon_enabled = false
  depends_on        = [module.custom_network]
}

locals {
  cluster_membership_id = var.cluster_membership_id == "" ? local.cluster_name : var.cluster_membership_id
  host                  = var.private_cluster ? "https://connectgateway.googleapis.com/v1/projects/${data.google_project.project.number}/locations/${var.cluster_location}/gkeMemberships/${local.cluster_membership_id}" : "https://${module.gke_cluster.endpoint}"

}

provider "kubernetes" {
  alias                  = "metaflow"
  host                   = local.host
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = var.private_cluster ? "" : base64decode(module.gke_cluster.ca_certificate)

  dynamic "exec" {
    for_each = var.private_cluster ? [1] : []
    content {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
}

provider "kubectl" {
  alias                  = "metaflow"
  apply_retry_count      = 1
  host                   = local.host
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = var.private_cluster ? "" : base64decode(module.gke_cluster.ca_certificate)
  load_config_file       = false

  dynamic "exec" {
    for_each = var.private_cluster ? [1] : []
    content {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
}

