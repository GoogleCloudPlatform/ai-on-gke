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

# Used to generate ip address
resource "random_string" "random" {
  length  = 4
  special = false
  upper   = false
}

# TODO refactor Jupyter and Frontend to be one
# Jupyter IAP
resource "google_compute_global_address" "jupyter_ip_address" {
  count        = var.jupyter_add_auth && var.jupyter_url_domain_addr == "" ? 1 : 0
  provider     = google-beta
  project      = var.project_id
  name         = "jupyter-address-${random_string.random.result}"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

# Helm Chart IAP
resource "helm_release" "iap_jupyter" {
  count            = var.jupyter_add_auth ? 1 : 0
  name             = "iap-jupyter"
  chart            = "${path.module}/charts/iap/"
  namespace        = var.namespace
  create_namespace = true 
  # timeout increased to support autopilot scaling resources, and give enough time to complete the deployment 
  timeout = 1200
  set {
    name  = "iap.backendConfig.name"
    value = var.jupyter_k8s_backend_config_name
  }

  set {
    name  = "iap.secret.name"
    value = var.jupyter_k8s_iap_secret_name
  }

  set {
    name  = "iap.secret.client_id"
    value = base64encode(var.jupyter_client_id)
  }

  set {
    name  = "iap.secret.client_secret"
    value = base64encode(var.jupyter_client_secret)
  }

  set {
    name  = "iap.managedCertificate.name"
    value = var.jupyter_k8s_managed_cert_name
  }

  set {
    name  = "iap.managedCertificate.domain"
    value = var.jupyter_url_domain_addr != "" ? var.jupyter_url_domain_addr : "${google_compute_global_address.jupyter_ip_address[0].address}.nip.io"
  }

  set {
    name  = "iap.ingress.staticIpName"
    value = var.jupyter_url_domain_addr != "" ? var.jupyter_url_domain_name : "${google_compute_global_address.jupyter_ip_address[0].name}"
  }

  set {
    name  = "iap.ingress.name"
    value = var.jupyter_k8s_ingress_name
  }

  set {
    name  = "iap.ingress.backendServiceName"
    value = var.jupyter_k8s_backend_service_name
  }

  set {
    name  = "iap.ingress.backendServicePort"
    value = var.jupyter_k8s_backend_service_port
  }
}

# TODO set the member allowlist

# Frontend IAP
resource "google_compute_global_address" "frontend_ip_address" {
  count        = var.frontend_add_auth && var.frontend_url_domain_addr == "" ? 1 : 0
  provider     = google-beta
  project      = var.project_id
  name         = "frontend-address-${random_string.random.result}"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

# Helm Chart IAP
resource "helm_release" "iap_frontend" {
  count            = var.frontend_add_auth ? 1 : 0
  name             = "iap-frontend"
  chart            = "${path.module}/charts/iap/"
  namespace        = var.namespace
  create_namespace = true 
  # timeout increased to support autopilot scaling resources, and give enough time to complete the deployment
  timeout = 1200
  set {
    name  = "iap.backendConfig.name"
    value = var.frontend_k8s_backend_config_name
  }

  set {
    name  = "iap.secret.name"
    value = var.frontend_k8s_iap_secret_name
  }

  set {
    name  = "iap.secret.client_id"
    value = base64encode(var.frontend_client_id)
  }

  set {
    name  = "iap.secret.client_secret"
    value = base64encode(var.frontend_client_secret)
  }

  set {
    name  = "iap.managedCertificate.name"
    value = var.frontend_k8s_managed_cert_name
  }

  set {
    name  = "iap.managedCertificate.domain"
    value = var.frontend_url_domain_addr != "" ? var.frontend_url_domain_addr : "${google_compute_global_address.frontend_ip_address[0].address}.nip.io"
  }

  set {
    name  = "iap.ingress.staticIpName"
    value = var.frontend_url_domain_addr != "" ? var.frontend_url_domain_name : "${google_compute_global_address.frontend_ip_address[0].name}"
  }

  set {
    name  = "iap.ingress.name"
    value = var.frontend_k8s_ingress_name
  }

  set {
    name  = "iap.ingress.backendServiceName"
    value = var.frontend_k8s_backend_service_name
  }

  set {
    name  = "iap.ingress.backendServicePort"
    value = var.frontend_k8s_backend_service_port
  }
}