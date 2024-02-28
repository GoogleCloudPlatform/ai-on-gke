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

provider "google" {
  project = var.project_id
}
provider "google-beta" {
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

data "kubernetes_all_namespaces" "allns" {}

module "kuberay-operator" {
  source                 = "../../modules/kuberay-operator"
  project_id             = var.project_id
  create_namespace       = !contains(data.kubernetes_all_namespaces.allns.namespaces, var.kubernetes_namespace)
  namespace              = var.kubernetes_namespace
  name                   = "kuberay-operator"
  google_service_account = var.ray_service_account
  create_service_account = var.create_ray_service_account
  enable_autopilot       = data.google_container_cluster.default.enable_autopilot
}

module "gcs" {
  source      = "../../modules/gcs"
  count       = var.create_gcs_bucket ? 1 : 0
  project_id  = var.project_id
  bucket_name = var.gcs_bucket
}

module "cloudsql" {
  source     = "../../modules/cloudsql"
  depends_on = [module.kuberay-operator]
  project_id = var.project_id
  namespace  = var.kubernetes_namespace
}

module "jupyterhub" {
  source     = "../../modules/jupyter"
  depends_on = [module.kuberay-operator, module.gcs]
  namespace  = var.kubernetes_namespace
  project_id = var.project_id
  gcs_bucket = var.gcs_bucket
  add_auth   = false # TODO: Replace with IAP.

  workload_identity_service_account = var.jupyter_service_account

  # IAP Auth parameters
  brand                     = var.brand
  support_email             = var.support_email
  client_id                 = var.client_id
  client_secret             = var.client_secret
  k8s_ingress_name          = var.k8s_ingress_name
  k8s_backend_config_name   = var.k8s_backend_config_name
  k8s_backend_service_name  = var.k8s_backend_service_name
  url_domain_addr           = var.url_domain_addr
  url_domain_name           = var.url_domain_name
  members_allowlist         = var.members_allowlist
}

module "kuberay-logging" {
  source     = "../../modules/kuberay-logging"
  depends_on = [module.kuberay-operator]
  namespace  = var.kubernetes_namespace
}

module "kuberay-cluster" {
  source                 = "../../modules/kuberay-cluster"
  project_id             = var.project_id
  depends_on             = [module.kuberay-operator, module.gcs, module.kuberay-monitoring]
  namespace              = var.kubernetes_namespace
  gcs_bucket             = var.gcs_bucket
  create_namespace       = !contains(data.kubernetes_all_namespaces.allns.namespaces, var.kubernetes_namespace)
  enable_tpu             = data.google_container_cluster.default.enable_tpu
  enable_gpu             = true
  enable_autopilot       = data.google_container_cluster.default.enable_autopilot
  google_service_account = var.ray_service_account
  grafana_host           = module.kuberay-monitoring.grafana_uri
}

module "kuberay-monitoring" {
  source                          = "../../modules/kuberay-monitoring"
  depends_on                      = [module.kuberay-operator]
  project_id                      = var.project_id
  namespace                       = var.kubernetes_namespace
  create_namespace                = !contains(data.kubernetes_all_namespaces.allns.namespaces, var.kubernetes_namespace)
  enable_grafana_on_ray_dashboard = var.enable_grafana_on_ray_dashboard
  k8s_service_account             = var.ray_service_account
}

module "inference-server" {
  source     = "../../tutorials/hf-tgi"
  depends_on = [module.kuberay-operator]
  namespace  = var.kubernetes_namespace
}

module "frontend" {
  source                        = "./frontend"
  depends_on                    = [module.cloudsql, module.gcs, module.inference-server]
  project_id                    = var.project_id
  create_service_account        = var.create_rag_service_account
  google_service_account        = var.rag_service_account
  namespace                     = var.kubernetes_namespace
  inference_service_name        = module.inference-server.inference_service_name
  inference_service_namespace   = module.inference-server.inference_service_namespace
  db_secret_name                = module.cloudsql.db_secret_name
  db_secret_namespace           = module.cloudsql.db_secret_namespace
  dataset_embeddings_table_name = var.dataset_embeddings_table_name
}
