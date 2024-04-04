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

locals {
  // add support for wildcard DNS ex; {IP_ADDRESS}.example.com
  domain = startswith(var.domain, "{IP_ADDRESS}.") ? "${google_compute_global_address.ip_address.address}.${trimprefix(var.domain, "{IP_ADDRESS}.")}" : var.domain
}

resource "terraform_data" "domain_validation" {
  input = timestamp()

  lifecycle {
    precondition {
      condition     = var.domain != ""
      error_message = "IAP configuration requires domain name, Please provide a valid domain name for ${var.app_name} application."
    }

    precondition {
      condition     = length(var.members_allowlist) != 0
      error_message = "IAP configuration requires allowlisting users. Please provide a valid allowlist for ${var.app_name} application."
    }
  }
}

data "google_project" "project" {
  project_id = var.project_id
}

# Creates a "Brand", equivalent to the OAuth consent screen on Cloud console
resource "google_iap_brand" "project_brand" {
  count             = var.create_brand ? 1 : 0
  support_email     = var.support_email
  application_title = "Web Application"
  project           = var.project_id
}

# IAP Section: Creates the OAuth client used in IAP
resource "google_iap_client" "iap_oauth_client" {
  count        = var.client_id == "" ? 1 : 0
  display_name = "${var.app_name}-Client"
  brand        = "projects/${data.google_project.project.number}/brands/${data.google_project.project.number}"
  depends_on   = [google_iap_brand.project_brand]
}

# Used to generate ip address
resource "random_string" "random" {
  length  = 4
  special = false
  upper   = false
}

# IAP
resource "google_compute_global_address" "ip_address" {
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
  # Timeout is increased to guarantee sufficient scale-up time for Autopilot nodes.
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
    value = local.domain
  }

  set {
    name  = "iap.ingress.staticIpName"
    value = google_compute_global_address.ip_address.name
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

resource "kubernetes_annotations" "annotation" {
  api_version = "v1"
  kind        = "Service"
  metadata {
    name      = var.k8s_backend_service_name
    namespace = var.namespace
  }
  annotations = {
    # Ingress will be auto updated
    "cloud.google.com/neg"                 = "{\"ingress\": true}"
    "beta.cloud.google.com/backend-config" = "{\"default\": \"${var.k8s_backend_config_name}\"}"
  }

  depends_on = [helm_release.iap]
}

## TODO(@umeshkumhar): grant permission to specific backend_service
resource "google_project_iam_member" "project" {
  for_each = toset(var.members_allowlist)
  project  = var.project_id
  role     = "roles/iap.httpsResourceAccessor"
  member   = each.key
}
