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

locals {
  cloudsql_instance_connection_name = var.cloudsql_instance_name != "" ? format("%s:%s:%s", var.project_id, var.db_region, var.cloudsql_instance_name) : ""
  additional_labels = tomap({
    for item in split(",", var.additional_labels) :
    split("=", item)[0] => split("=", item)[1]
  })
}

# IAP Section: Creates the GKE components
module "iap_auth" {
  count  = var.add_auth ? 1 : 0
  source = "../../modules/iap"

  project_id               = var.project_id
  namespace                = var.namespace
  app_name                 = "jupyter"
  create_brand             = var.create_brand
  support_email            = var.support_email
  k8s_ingress_name         = var.k8s_ingress_name
  k8s_managed_cert_name    = var.k8s_managed_cert_name
  k8s_iap_secret_name      = var.k8s_iap_secret_name
  k8s_backend_config_name  = var.k8s_backend_config_name
  k8s_backend_service_name = var.k8s_backend_service_name
  k8s_backend_service_port = var.k8s_backend_service_port
  client_id                = var.client_id
  client_secret            = var.client_secret
  domain                   = var.domain
  members_allowlist        = var.members_allowlist
  depends_on = [
    helm_release.jupyterhub
  ]
}

module "jupyterhub-workload-identity" {
  source     = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version    = "30.0.0" # Pinning to a previous version as current version (30.1.0) showed inconsitent behaviour with workload identity service accounts
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
    "iam.gke.io/gcp-service-account" = module.jupyterhub-workload-identity.gcp_service_account_email
  }
  depends_on = [
    helm_release.jupyterhub,
  ]
}

resource "google_service_account_iam_binding" "hub-workload-identity-user" {
  count              = var.add_auth ? 1 : 0
  service_account_id = module.jupyterhub-workload-identity.gcp_service_account.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/hub]",
    "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.workload_identity_service_account}]",
  ]
  depends_on = [
    helm_release.jupyterhub
  ]
}


resource "google_storage_bucket_iam_member" "gcs-bucket-iam" {
  bucket = var.gcs_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${module.jupyterhub-workload-identity.gcp_service_account_email}"
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
  create_namespace = true
  cleanup_on_fail  = "true"
  timeout          = 600
  version          = "3.3.8"

  values = var.autopilot_cluster ? [templatefile("${path.module}/jupyter_config/config-selfauth-autopilot.yaml", {
    password                          = var.add_auth ? "dummy" : random_password.generated_password[0].result
    project_id                        = var.project_id
    project_number                    = data.google_project.project.number
    namespace                         = var.namespace
    additional_labels                 = local.additional_labels
    backend_config                    = var.k8s_backend_config_name
    service_name                      = var.k8s_backend_service_name
    authenticator_class               = var.add_auth ? "'gcpiapjwtauthenticator.GCPIAPAuthenticator'" : "dummy"
    service_type                      = var.add_auth ? "NodePort" : "ClusterIP"
    gcs_bucket                        = var.gcs_bucket
    k8s_service_account               = var.workload_identity_service_account
    ephemeral_storage                 = var.ephemeral_storage
    secret_name                       = var.db_secret_name
    cloudsql_instance_connection_name = local.cloudsql_instance_connection_name

    notebook_image     = var.notebook_image
    notebook_image_tag = var.notebook_image_tag
    })
    ] : [templatefile("${path.module}/jupyter_config/config-selfauth.yaml", {
      password                          = var.add_auth ? "dummy" : random_password.generated_password[0].result
      project_id                        = var.project_id
      project_number                    = data.google_project.project.number
      namespace                         = var.namespace
      additional_labels                 = local.additional_labels
      backend_config                    = var.k8s_backend_config_name
      service_name                      = var.k8s_backend_service_name
      authenticator_class               = var.add_auth ? "'gcpiapjwtauthenticator.GCPIAPAuthenticator'" : "dummy"
      service_type                      = var.add_auth ? "NodePort" : "ClusterIP"
      gcs_bucket                        = var.gcs_bucket
      k8s_service_account               = var.workload_identity_service_account
      ephemeral_storage                 = var.ephemeral_storage
      secret_name                       = var.db_secret_name
      cloudsql_instance_connection_name = local.cloudsql_instance_connection_name
      notebook_image                    = var.notebook_image
      notebook_image_tag                = var.notebook_image_tag
    })
  ]
  depends_on = [module.jupyterhub-workload-identity]
}

data "kubernetes_service" "jupyter" {
  metadata {
    name      = var.k8s_backend_service_name
    namespace = var.namespace
  }
  depends_on = [module.iap_auth, helm_release.jupyterhub]
}

