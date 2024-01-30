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
  cluster_membership_id = local.private_cluster ? element(split("/", data.google_container_cluster.default.fleet.0.membership), length(split("/", data.google_container_cluster.default.fleet.0.membership)) - 1) : ""
}

provider "kubernetes" {
  host                   = local.private_cluster ? "https://connectgateway.googleapis.com/v1/projects/${data.google_project.project.number}/locations/global/gkeMemberships/${local.cluster_membership_id}" : "https://${data.google_container_cluster.default.endpoint}"
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
    host                   = local.private_cluster ? "https://connectgateway.googleapis.com/v1/projects/${data.google_project.project.number}/locations/global/gkeMemberships/${local.cluster_membership_id}" : "https://${data.google_container_cluster.default.endpoint}"
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
}

module "kubernetes-namespace" {
  source     = "../../modules/kubernetes-namespace"
  depends_on = [module.kuberay-operator]
  namespace  = var.ray_namespace
}

module "k8s_service_accounts" {
  source          = "../../modules/service_accounts"
  project_id      = var.project_id
  namespace       = var.ray_namespace
  service_account = var.service_account
  depends_on      = [module.kubernetes-namespace]
}

module "kuberay-cluster" {
  count      = var.create_ray_cluster == true ? 1 : 0
  source     = "../../modules/kuberay-cluster"
  depends_on = [module.kubernetes-namespace]
  namespace  = var.ray_namespace
  enable_tpu = var.support_tpu
}

module "prometheus" {
  count      = var.create_ray_cluster == true ? 1 : 0
  source     = "../../modules/prometheus"
  depends_on = [module.kuberay-cluster, module.kubernetes-namespace]
  project_id = var.project_id
  namespace  = var.ray_namespace
}
