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

data "google_client_config" "default" {}

data "google_project" "project" {
  project_id = var.project_id
}

data "google_container_cluster" "default" {
  name     = var.cluster_name
  location = var.cluster_location
}

locals {
  private_cluster       = data.google_container_cluster.default.private_cluster_config.0.enable_private_endpoint
  cluster_membership_id = var.cluster_membership_id == "" ? var.cluster_name : var.cluster_membership_id
}

provider "kubernetes" {
  host                   = local.private_cluster ? "https://connectgateway.googleapis.com/v1/projects/${data.google_project.project.number}/locations/${var.cluster_location}/gkeMemberships/${local.cluster_membership_id}" : "https://${data.google_container_cluster.default.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = local.private_cluster ? "" : base64decode(data.google_container_cluster.default.master_auth[0].cluster_ca_certificate)
  dynamic "exec" {
    for_each = local.private_cluster ? [1] : []
    content {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = local.private_cluster ? "https://connectgateway.googleapis.com/v1/projects/${data.google_project.project.number}/locations/${var.cluster_location}/gkeMemberships/${local.cluster_membership_id}" : "https://${data.google_container_cluster.default.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = local.private_cluster ? "" : base64decode(data.google_container_cluster.default.master_auth[0].cluster_ca_certificate)
    dynamic "exec" {
      for_each = local.private_cluster ? [1] : []
      content {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "gke-gcloud-auth-plugin"
      }
    }
  }
}


# fetch all namespaces
data "kubernetes_all_namespaces" "allns" {}

module "kuberay-operator" {
  source           = "../../modules/kuberay-operator"
  name             = "kuberay-operator"
  create_namespace = !contains(data.kubernetes_all_namespaces.allns.namespaces, var.ray_namespace)
  namespace        = var.ray_namespace
  enable_autopilot = data.google_container_cluster.default.enable_autopilot
}

module "kuberay_serviceaccounts" {
  source                          = "../../modules/kuberay-serviceaccounts"
  project_id                      = var.project_id
  namespace                       = var.ray_namespace
  create_k8s_service_account_prom = var.create_k8s_service_account_prom
  k8s_service_account_prom        = var.k8s_service_account_prom
  gcp_service_account_prom        = var.gcp_service_account_prom

  create_k8s_service_account_gcs = var.create_k8s_service_account_gcs
  k8s_service_account_gcs        = var.k8s_service_account_gcs
  gcp_service_account_gcs        = var.gcp_service_account_gcs
  gcs_bucket                     = var.gcs_bucket

  depends_on = [ module.kuberay-operator ]
}

module "kuberay-logging" {
  source     = "../../modules/kuberay-logging"
  namespace  = var.ray_namespace

  depends_on = [module.kuberay-operator]
}

module "kuberay-monitoring" {
  count               = var.create_ray_cluster == true ? 1 : 0
  source              = "../../modules/kuberay-monitoring"
  project_id          = var.project_id
  namespace           = var.ray_namespace
  create_namespace    = !contains(data.kubernetes_all_namespaces.allns.namespaces, var.ray_namespace)
  k8s_service_account = var.k8s_service_account_prom

  depends_on = [ module.kuberay_serviceaccounts ]
}

module "kuberay-cluster" {
  count               = var.create_ray_cluster == true ? 1 : 0
  source              = "../../modules/kuberay-cluster"
  create_namespace    = !contains(data.kubernetes_all_namespaces.allns.namespaces, var.ray_namespace)
  namespace           = var.ray_namespace
  enable_tpu          = data.google_container_cluster.default.enable_tpu
  gcs_bucket          = var.gcs_bucket
  enable_autopilot    = data.google_container_cluster.default.enable_autopilot
  k8s_service_account = var.k8s_service_account_gcs
  grafana_host        = module.kuberay-monitoring[0].grafana_uri

  depends_on = [module.kuberay-monitoring]
}

