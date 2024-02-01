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

# Reserve IP Address
resource "google_compute_global_address" "default" {
  count        = var.url_domain_addr != "" ? 0 : 1
  provider     = google-beta
  project      = var.project_id
  name         = "jupyter-address"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

# fetch all namespaces
data "kubernetes_all_namespaces" "allns" {}

# Helm Chart IAP
resource "helm_release" "iap_jupyter" {
  name             = "iap-jupyter"
  chart            = "${path.module}/charts/iap_jupyter/"
  namespace        = var.namespace
  create_namespace = !contains(data.kubernetes_all_namespaces.allns.namespaces, var.namespace)

  set {
    name  = "iap.backendConfig.name"
    value = var.service_name
  }

  set {
    name  = "iap.backendConfig.iapSecretName"
    value = var.iap_client_secret
  }

  set {
    name  = "iap.secret.client_id"
    value = base64encode(var.client_id)
  }

  set {
    name  = "iap.secret.client_secret"
    value = base64encode(var.client_secret)
  }

  set {
    name  = "iap.managedCertificate.domain"
    value = var.url_domain_addr != "" ? var.url_domain_addr : "${google_compute_global_address.default[0].address}.nip.io"
  }

  set {
    name  = "iap.jupyterIngress.staticIpName"
    value = var.url_domain_addr != "" ? var.url_domain_name : "${google_compute_global_address.default[0].name}"
  }

  set {
    name  = "iap.jupyterIngress.defaultBackend"
    value = var.default_backend_service
  }
}

