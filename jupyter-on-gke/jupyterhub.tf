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

provider "kubernetes" {
  config_path = pathexpand("~/.kube/config")
}

provider "kubectl" {
  config_path = pathexpand("~/.kube/config")
}

provider "helm" {
  kubernetes {
    config_path = pathexpand("~/.kube/config")
  }
}

provider "google-beta" {
  project = var.project_id
  region  = var.location
}

data "google_project" "project" {
  project_id = var.project_id
}

# The data of the GCP backend service. IAP is enabled on this backend service
data "google_compute_backend_service" "jupyter-ingress" {
  name    = var.service_name
  project = var.project_id
}

resource "google_iap_web_backend_service_iam_binding" "binding" {
  count               = var.add_auth && data.google_compute_backend_service.jupyter-ingress.generated_id != null ? 1 : 0
  project             = var.project_id
  web_backend_service = var.add_auth && data.google_compute_backend_service.jupyter-ingress.generated_id != null ? "${data.google_compute_backend_service.jupyter-ingress.name}" : "no-id-yet"
  role                = "roles/iap.httpsResourceAccessor"
  members             = split("\n", chomp(file("${path.module}/allowlist")))
}

# Enabled the IAP service 
resource "google_project_service" "project_service" {
  count   = var.enable_iap_service ? 1 : 0
  project = var.project_id
  service = "iap.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

# Creates a "Brand", equivalent to the OAuth consent screen on GCP UI
resource "google_iap_brand" "project_brand" {
  count             = var.brand != "" ? 1 : 0
  support_email     = var.support_email
  application_title = "Cloud IAP protected Application"
  project           = var.project_id
}

# Creates the OAuth client used in IAP
resource "google_iap_client" "iap_oauth_client" {
  display_name = "Jupyter-Client"
  brand        = "projects/${data.google_project.project.number}/brands/${data.google_project.project.number}"
}

resource "kubernetes_namespace" "namespace" {
  count = var.create_namespace ? 1 : 0
  metadata {
    labels = {
      namespace = var.namespace
    }

    name = var.namespace
  }
}

module "iap_auth" {
  count  = var.add_auth ? 1 : 0
  source = "./iap_module"

  project_id      = var.project_id
  namespace       = var.namespace
  service_name    = var.service_name
  client          = google_iap_client.iap_oauth_client
  url_domain_addr = var.url_domain_addr
  url_domain_name = var.url_domain_name

  depends_on = [
    helm_release.jupyterhub,
    kubernetes_namespace.namespace,
  ]
}

resource "helm_release" "jupyterhub" {
  name            = "jupyterhub"
  repository      = "https://jupyterhub.github.io/helm-chart"
  chart           = "jupyterhub"
  namespace       = var.namespace
  cleanup_on_fail = "true"

  values = [
    templatefile("${path.module}/jupyter_config/config-selfauth.yaml", {
      service_id     = var.add_auth && data.google_compute_backend_service.jupyter-ingress.generated_id != null ? "${data.google_compute_backend_service.jupyter-ingress.generated_id}" : "no-id-yet"
      project_number = data.google_project.project.number
      authenticator_class = var.add_auth ? "'gcpiapjwtauthenticator.GCPIAPAuthenticator'" : "dummy"
      service_type = var.add_auth ? "NodePort" : "LoadBalancer"
    })
  ]

  depends_on = [
    kubernetes_namespace.namespace
  ]
}

