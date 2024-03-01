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

# create namespace
module "namespace" {
  source           = "../../modules/kubernetes-namespace"
  namespace        = var.namespace
  create_namespace = !contains(data.kubernetes_all_namespaces.allns.namespaces, var.namespace)
}

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
  source = "../../modules/iap"

  project_id                        = var.project_id
  namespace                         = var.namespace
  jupyter_add_auth                  = var.add_auth
  jupyter_k8s_ingress_name          = var.k8s_ingress_name
  jupyter_k8s_managed_cert_name     = var.k8s_managed_cert_name
  jupyter_k8s_iap_secret_name       = var.k8s_iap_secret_name
  jupyter_k8s_backend_config_name   = var.k8s_backend_config_name
  jupyter_k8s_backend_service_name  = var.k8s_backend_service_name
  jupyter_k8s_backend_service_port  = var.k8s_backend_service_port
  jupyter_client_id                 = var.client_id != "" ? var.client_id : google_iap_client.iap_oauth_client[0].client_id
  jupyter_client_secret             = var.client_id != "" ? var.client_secret : google_iap_client.iap_oauth_client[0].secret
  jupyter_url_domain_addr           = var.url_domain_addr
  jupyter_url_domain_name           = var.url_domain_name
  depends_on                = [
    google_project_service.project_service,
    helm_release.jupyterhub
  ]
}

module "jupyterhub-workload-identity" {
  source     = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  name       = var.workload_identity_service_account
  namespace  = var.namespace
  project_id = var.project_id
  roles      = concat(var.predefined_iam_roles, var.gcp_service_account_iam_roles)
}

resource "kubernetes_annotations" "hub" {
  api_version = "v1"
  kind        = "ServiceAccount"
  metadata {
    name      = "hub"
    namespace = var.namespace
  }
  annotations = {
    "iam.gke.io/gcp-service-account" = "${var.workload_identity_service_account}@${var.project_id}.iam.gserviceaccount.com"
  }
  depends_on = [
    helm_release.jupyterhub,
    module.jupyterhub-workload-identity
  ]
}

data "google_service_account" "sa" {
  account_id = var.workload_identity_service_account
  depends_on = [
    helm_release.jupyterhub,
    module.jupyterhub-workload-identity
  ]
}

resource "google_service_account_iam_binding" "hub-workload-identity-user" {
  count                     = var.add_auth ? 1 : 0
  service_account_id        = data.google_service_account.sa.name
  role                      = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/hub]",
    "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.workload_identity_service_account}]",
  ]
  depends_on = [
    helm_release.jupyterhub,
    module.jupyterhub-workload-identity
  ]
}



resource "google_storage_bucket_iam_member" "gcs-bucket-iam" {
  bucket     = var.gcs_bucket
  role       = "roles/storage.objectAdmin"
  member     = "serviceAccount:${var.workload_identity_service_account}@${var.project_id}.iam.gserviceaccount.com"
  depends_on = [module.jupyterhub-workload-identity]
}

resource "random_password" "generated_password" {
  count   = var.add_auth ? 0 : 1
  length  = 10
  special = false
}

resource "helm_release" "jupyterhub" {
  name             = "jupyterhub"
  repository       = "https://jupyterhub.github.io/helm-chart"
  chart            = "jupyterhub"
  namespace        = var.namespace
  create_namespace = !contains(data.kubernetes_all_namespaces.allns.namespaces, var.namespace)
  cleanup_on_fail  = "true"
  # This timeout is sufficient and ensures terraform doesn't hang for 20 minutes on error.
  # Autopilot deployment will complete even faster than Standard, as it relies on Ray Autoscaler to provision user pods.
  timeout = 300

  values = var.autopilot_cluster ? [ templatefile("${path.module}/jupyter_config/config-selfauth-autopilot.yaml", {
      password            = var.add_auth ? "dummy" : random_password.generated_password[0].result
      project_id          = var.project_id
      project_number      = data.google_project.project.number
      namespace           = var.namespace
      backend_config      = var.k8s_backend_config_name
      service_name        = var.k8s_backend_service_name
      authenticator_class = var.add_auth ? "'gcpiapjwtauthenticator.GCPIAPAuthenticator'" : "dummy"
      service_type        = var.add_auth ? "NodePort" : "LoadBalancer"
      gcs_bucket          = var.gcs_bucket
      k8s_service_account = var.workload_identity_service_account
      ephemeral_storage   = var.ephemeral_storage
    })
    ] : [templatefile("${path.module}/jupyter_config/config-selfauth.yaml", {
      password       = var.add_auth ? "dummy" : random_password.generated_password[0].result
      project_id     = var.project_id
      project_number = data.google_project.project.number

      # Support legacy image.
      service_id          = "" # TODO(umeshkumhar): var.add_auth ? (data.google_compute_backend_service.jupyter-ingress[0].generated_id != null ? data.google_compute_backend_service.jupyter-ingress[0].generated_id : "no-id-yet") : "no-id-yet"
      namespace           = var.namespace
      backend_config      = var.k8s_backend_config_name
      service_name        = var.k8s_backend_service_name
      authenticator_class = var.add_auth ? "'gcpiapjwtauthenticator.GCPIAPAuthenticator'" : "dummy"
      service_type        = var.add_auth ? "NodePort" : "LoadBalancer"
      gcs_bucket          = var.gcs_bucket
      k8s_service_account = var.workload_identity_service_account
      ephemeral_storage   = var.ephemeral_storage
    })
  ]
  depends_on = [ module.jupyterhub-workload-identity ]
}

data "kubernetes_service" "jupyter-ingress" {
  metadata {
    name      = var.k8s_ingress_name
    namespace = var.namespace
  }
  depends_on = [module.iap_auth]
}