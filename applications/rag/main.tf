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

module "infra" {
  source = "../../infrastructure"
  count  = var.create_cluster ? 1 : 0

  project_id        = var.project_id
  cluster_name      = var.cluster_name
  cluster_location  = var.cluster_location
  autopilot_cluster = var.autopilot_cluster
  private_cluster   = var.private_cluster
  create_network    = false
  network_name      = "default"
  subnetwork_name   = "default"
  cpu_pools         = var.cpu_pools
  enable_gpu        = true
  gpu_pools         = var.gpu_pools
}

data "google_container_cluster" "default" {
  count    = var.create_cluster ? 0 : 1
  name     = var.cluster_name
  location = var.cluster_location
}

locals {
  endpoint              = var.create_cluster ? "https://${module.infra[0].endpoint}" : "https://${data.google_container_cluster.default[0].endpoint}"
  ca_certificate        = var.create_cluster ? base64decode(module.infra[0].ca_certificate) : base64decode(data.google_container_cluster.default[0].master_auth[0].cluster_ca_certificate)
  private_cluster       = var.create_cluster ? var.private_cluster : data.google_container_cluster.default[0].private_cluster_config.0.enable_private_endpoint
  cluster_membership_id = var.cluster_membership_id == "" ? var.cluster_name : var.cluster_membership_id
  enable_autopilot      = var.create_cluster ? var.autopilot_cluster : data.google_container_cluster.default[0].enable_autopilot
  host                  = local.private_cluster ? "https://connectgateway.googleapis.com/v1/projects/${data.google_project.project.number}/locations/${var.cluster_location}/gkeMemberships/${local.cluster_membership_id}" : local.endpoint
}

## Generated names for marketplace deployment
locals {
  ray_service_account     = var.goog_cm_deployment_name != "" ? "${var.goog_cm_deployment_name}-${var.ray_service_account}" : var.ray_service_account
  jupyter_service_account = var.goog_cm_deployment_name != "" ? "${var.goog_cm_deployment_name}-${var.jupyter_service_account}" : var.jupyter_service_account
  rag_service_account     = var.goog_cm_deployment_name != "" ? "${var.goog_cm_deployment_name}-${var.rag_service_account}" : var.rag_service_account
  frontend_default_uri    = "https://console.cloud.google.com/kubernetes/service/${var.cluster_location}/${var.cluster_name}/${var.kubernetes_namespace}/rag-frontend/overview?project=${var.project_id}"
  ## if cloudsql_instance_region not specified, then default to cluster_location region
  cloudsql_instance_region = var.cloudsql_instance_region != "" ? var.cloudsql_instance_region : (length(split("-", var.cluster_location)) == 2 ? var.cluster_location : join("-", slice(split("-", var.cluster_location), 0, 2)))
}


provider "kubernetes" {
  alias                  = "rag"
  host                   = local.host
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = local.private_cluster ? "" : local.ca_certificate
  dynamic "exec" {
    for_each = local.private_cluster ? [1] : []
    content {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
}

provider "helm" {
  alias = "rag"
  kubernetes {
    host                   = local.host
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = local.private_cluster ? "" : local.ca_certificate
    dynamic "exec" {
      for_each = local.private_cluster ? [1] : []
      content {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "gke-gcloud-auth-plugin"
      }
    }
  }
}

module "namespace" {
  source           = "../../modules/kubernetes-namespace"
  providers        = { helm = helm.rag }
  create_namespace = true
  namespace        = var.kubernetes_namespace
}

module "kuberay-operator" {
  source                 = "../../modules/kuberay-operator"
  providers              = { helm = helm.rag, kubernetes = kubernetes.rag }
  name                   = "kuberay-operator"
  project_id             = var.project_id
  create_namespace       = true
  namespace              = var.kubernetes_namespace
  google_service_account = local.ray_service_account
  create_service_account = var.create_ray_service_account
  autopilot_cluster      = local.enable_autopilot
}

module "gcs" {
  source      = "../../modules/gcs"
  count       = var.create_gcs_bucket ? 1 : 0
  project_id  = var.project_id
  bucket_name = var.gcs_bucket
}

module "cloudsql" {
  source        = "../../modules/cloudsql"
  providers     = { kubernetes = kubernetes.rag }
  project_id    = var.project_id
  instance_name = var.cloudsql_instance
  namespace     = var.kubernetes_namespace
  region        = local.cloudsql_instance_region
  depends_on    = [module.namespace]
}

# IAP Section: Enabled the IAP service
resource "google_project_service" "project_service" {
  count   = var.frontend_add_auth || var.jupyter_add_auth ? 1 : 0
  project = var.project_id
  service = "iap.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

module "jupyterhub" {
  source     = "../../modules/jupyter"
  providers  = { helm = helm.rag, kubernetes = kubernetes.rag }
  namespace  = var.kubernetes_namespace
  project_id = var.project_id
  gcs_bucket = var.gcs_bucket
  add_auth   = var.jupyter_add_auth

  autopilot_cluster                 = local.enable_autopilot
  workload_identity_service_account = local.jupyter_service_account

  # IAP Auth parameters
  brand                    = var.brand
  support_email            = var.jupyter_support_email
  client_id                = var.jupyter_client_id
  client_secret            = var.jupyter_client_secret
  k8s_ingress_name         = var.jupyter_k8s_ingress_name
  k8s_iap_secret_name      = var.jupyter_k8s_iap_secret_name
  k8s_managed_cert_name    = var.jupyter_k8s_managed_cert_name
  k8s_backend_config_name  = var.jupyter_k8s_backend_config_name
  k8s_backend_service_name = var.jupyter_k8s_backend_service_name
  k8s_backend_service_port = var.jupyter_k8s_backend_service_port
  url_domain_addr          = var.jupyter_url_domain_addr
  url_domain_name          = var.jupyter_url_domain_name
  members_allowlist        = var.jupyter_members_allowlist

  depends_on = [module.namespace, module.gcs]
}

module "kuberay-logging" {
  source     = "../../modules/kuberay-logging"
  providers  = { kubernetes = kubernetes.rag }
  namespace  = var.kubernetes_namespace
  depends_on = [module.namespace]
}

module "kuberay-cluster" {
  source                 = "../../modules/kuberay-cluster"
  providers              = { helm = helm.rag, kubernetes = kubernetes.rag }
  project_id             = var.project_id
  namespace              = var.kubernetes_namespace
  enable_gpu             = true
  gcs_bucket             = var.gcs_bucket
  enable_tpu             = false
  autopilot_cluster      = local.enable_autopilot
  db_secret_name         = module.cloudsql.db_secret_name
  cloudsql_instance_name = var.cloudsql_instance
  db_region              = local.cloudsql_instance_region
  google_service_account = local.ray_service_account
  grafana_host           = module.kuberay-monitoring.grafana_uri
  disable_network_policy = var.disable_ray_cluster_network_policy
  depends_on             = [module.kuberay-operator]
}

module "kuberay-monitoring" {
  source                          = "../../modules/kuberay-monitoring"
  providers                       = { helm = helm.rag, kubernetes = kubernetes.rag }
  project_id                      = var.project_id
  namespace                       = var.kubernetes_namespace
  create_namespace                = true
  enable_grafana_on_ray_dashboard = var.enable_grafana_on_ray_dashboard
  k8s_service_account             = local.ray_service_account
  # TODO(umeshkumhar): remove kuberay-operator depends, figure out service account dependency
  depends_on = [module.namespace, module.kuberay-operator]
}

module "inference-server" {
  source            = "../../tutorials/hf-tgi"
  providers         = { kubernetes = kubernetes.rag }
  namespace         = var.kubernetes_namespace
  autopilot_cluster = local.enable_autopilot
  depends_on        = [module.namespace]
}

module "frontend" {
  source                        = "./frontend"
  providers                     = { helm = helm.rag, kubernetes = kubernetes.rag }
  project_id                    = var.project_id
  create_service_account        = var.create_rag_service_account
  google_service_account        = local.rag_service_account
  namespace                     = var.kubernetes_namespace
  inference_service_endpoint    = module.inference-server.inference_service_endpoint
  cloudsql_instance             = module.cloudsql.instance
  cloudsql_instance_region      = local.cloudsql_instance_region
  db_secret_name                = module.cloudsql.db_secret_name
  dataset_embeddings_table_name = var.dataset_embeddings_table_name

  # IAP Auth parameters
  add_auth                 = var.frontend_add_auth
  brand                    = var.brand
  support_email            = var.frontend_support_email
  client_id                = var.frontend_client_id
  client_secret            = var.frontend_client_secret
  k8s_ingress_name         = var.frontend_k8s_ingress_name
  k8s_managed_cert_name    = var.frontend_k8s_managed_cert_name
  k8s_iap_secret_name      = var.frontend_k8s_iap_secret_name
  k8s_backend_config_name  = var.frontend_k8s_backend_config_name
  k8s_backend_service_name = var.frontend_k8s_backend_service_name
  k8s_backend_service_port = var.frontend_k8s_backend_service_port
  url_domain_addr          = var.frontend_url_domain_addr
  url_domain_name          = var.frontend_url_domain_name
  members_allowlist        = var.frontend_members_allowlist
  depends_on               = [module.namespace]
}

