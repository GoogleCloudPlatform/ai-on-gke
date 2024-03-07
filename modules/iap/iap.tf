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

# IAP Section: Enabled the IAP service
data "google_project" "project" {
  project_id = var.project_id
}

# Creates a "Brand", equivalent to the OAuth consent screen on Cloud console
resource "google_iap_brand" "project_brand" {
  count             = var.brand == "" ? 1 : 0
  support_email     = var.support_email
  application_title = "${var.app_name}-Application"
  project           = var.project_id
}

# IAP Section: Creates the OAuth client used in IAP
resource "google_iap_client" "iap_oauth_client" {
  count        = var.client_id == "" ? 1 : 0
  display_name = "${var.app_name}-Client"
  brand        = var.brand == "" ? "projects/${data.google_project.project.number}/brands/${data.google_project.project.number}" : var.brand
}

# Used to generate ip address
resource "random_string" "random" {
  length  = 4
  special = false
  upper   = false
}

# IAP
resource "google_compute_global_address" "ip_address" {
  count        = var.url_domain_addr == "" ? 1 : 0
  provider     = google-beta
  project      = var.project_id
  name         = "${var.app_name}-address-${random_string.random.result}"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

# Helm Chart IAP
resource "helm_release" "iap" {
  name             = "${var.app_name}-iap"
  chart            = "${path.module}/charts/iap/"
  namespace        = var.namespace
  create_namespace = true
  # timeout increased to support autopilot scaling resources, and give enough time to complete the deployment
  timeout = 1200
  set {
    name  = "iap.backendConfig.name"
    value = var.k8s_backend_config_name
  }

  set {
    name  = "iap.secret.name"
    value = var.k8s_iap_secret_name
  }

  set {
    name  = "iap.secret.client_id"
    value = base64encode(var.client_id != "" ? var.client_id : google_iap_client.iap_oauth_client[0].client_id)
  }

  set {
    name  = "iap.secret.client_secret"
    value = base64encode(var.client_secret != "" ? var.client_secret : google_iap_client.iap_oauth_client[0].secret)
  }

  set {
    name  = "iap.managedCertificate.name"
    value = var.k8s_managed_cert_name
  }

  set {
    name  = "iap.managedCertificate.domain"
    value = var.url_domain_addr != "" ? var.url_domain_addr : "${google_compute_global_address.ip_address[0].address}.nip.io"
  }

  set {
    name  = "iap.ingress.staticIpName"
    value = var.url_domain_addr != "" ? var.url_domain_name : "${google_compute_global_address.ip_address[0].name}"
  }

  set {
    name  = "iap.ingress.name"
    value = var.k8s_ingress_name
  }

  set {
    name  = "iap.ingress.backendServiceName"
    value = var.k8s_backend_service_name
  }

  set {
    name  = "iap.ingress.backendServicePort"
    value = var.k8s_backend_service_port
  }
}