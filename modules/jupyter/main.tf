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

data "google_project" "project" {
  project_id = var.project_id
}

# fetch all namespaces
data "kubernetes_all_namespaces" "allns" {}

# Creates a "Brand", equivalent to the OAuth consent screen on Cloud console
resource "google_iap_brand" "project_brand" {
  count             = var.add_auth && var.brand == "" ? 1 : 0
  support_email     = var.support_email
  application_title = "Application"
  project           = var.project_id
}

# IAP Section: Enabled the IAP service 
resource "google_project_service" "project_service" {
  count   = var.add_auth ? 1 : 0
  project = var.project_id
  service = "iap.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

# IAP Section: Creates the OAuth client used in IAP
resource "google_iap_client" "iap_oauth_client" {
  count        = var.add_auth && var.client_id == "" ? 1 : 0
  display_name = "Jupyter-Client"
  brand        = var.brand == "" ? "projects/${data.google_project.project.number}/brands/${data.google_project.project.number}" : var.brand
}

# IAP Section: Creates the GKE components
module "iap_auth" {
  count  = var.add_auth ? 1 : 0
  source = "../../modules/jupyter_iap"

  project_id              = var.project_id
  namespace               = var.namespace
  default_backend_service = var.default_backend_service
  service_name            = var.service_name
  client_id               = var.client_id != "" ? var.client_id : google_iap_client.iap_oauth_client[0].client_id
  client_secret           = var.client_id != "" ? var.client_secret : google_iap_client.iap_oauth_client[0].secret
  url_domain_addr         = var.url_domain_addr
  url_domain_name         = var.url_domain_name
  depends_on              = [google_project_service.project_service]
}

module "workload_identity_service_account" {
  source = "../../modules/service_accounts"

  project_id      = var.project_id
  namespace       = var.namespace
  service_account = var.gcp_service_account
  sa_iam_roles    = split(",", var.gcp_service_account_iam_roles)
  depends_on      = [helm_release.jupyterhub]
}

resource "random_password" "generated_password" {
  count   = var.add_auth ? 0 : 1
  length  = 10
  special = false
}

resource "helm_release" "storage" {
  name             = "storage"
  chart            = "../../modules/jupyter_storage/charts"
  namespace        = var.namespace
  create_namespace = !contains(data.kubernetes_all_namespaces.allns.namespaces, var.namespace)
  cleanup_on_fail  = "true"

  values = [
    templatefile("../../modules/jupyter_storage/charts/values.yaml", {
      namespace           = var.namespace

    })
  ]
}

resource "helm_release" "jupyterhub" {
  name             = "jupyterhub"
  repository       = "https://jupyterhub.github.io/helm-chart"
  chart            = "jupyterhub"
  namespace        = var.namespace
  create_namespace = !contains(data.kubernetes_all_namespaces.allns.namespaces, var.namespace)
  cleanup_on_fail  = "true"

  values = [
    templatefile(var.enable_filestore_use ? "${path.module}/jupyter_config/config-filestore.yaml" : "${path.module}/jupyter_config/config-selfauth.yaml", {
      password            = var.add_auth ? "dummy" : random_password.generated_password[0].result
      service_id          = var.add_auth ? (data.google_compute_backend_service.jupyter-ingress[0].generated_id != null ? data.google_compute_backend_service.jupyter-ingress[0].generated_id : "no-id-yet") : "no-id-yet"
      backend_config      = var.service_name
      project_number      = data.google_project.project.number
      authenticator_class = var.add_auth ? "'gcpiapjwtauthenticator.GCPIAPAuthenticator'" : "dummy"
      service_type        = var.add_auth ? "NodePort" : "LoadBalancer"
      gcs_bucket          = var.gcs_bucket
      k8s_service_account = var.k8s_service_account
    })
  ]
  depends_on = [module.iap_auth]
}

# Need to re-apply: fetch service_id from deployed service
data "kubernetes_service" "jupyter-ingress" {
  metadata {
    name      = var.default_backend_service
    namespace = var.namespace
  }
  depends_on = [module.iap_auth]
}

# The data of the GCP backend service. IAP is enabled on this backend service
data "google_compute_backend_service" "jupyter-ingress" {
  count   = var.add_auth ? 1 : 0
  name    = data.kubernetes_service.jupyter-ingress.metadata != null ? (data.kubernetes_service.jupyter-ingress.metadata[0].annotations != null ? jsondecode(data.kubernetes_service.jupyter-ingress.metadata[0].annotations["cloud.google.com/neg-status"]).network_endpoint_groups["80"] : "not-found") : "not-found"
  project = var.project_id
}

# Binds the list of principals in the allowlist file to roles/iap.httpsResourceAccessor
resource "google_iap_web_backend_service_iam_binding" "binding" {
  count               = var.add_auth ? (data.google_compute_backend_service.jupyter-ingress[0].generated_id != null ? 1 : 0) : 0
  project             = var.project_id
  web_backend_service = data.google_compute_backend_service.jupyter-ingress[0].generated_id != null ? "${data.google_compute_backend_service.jupyter-ingress[0].name}" : "no-id-yet"
  role                = "roles/iap.httpsResourceAccessor"
  members             = split(",", var.members_allowlist)
}

