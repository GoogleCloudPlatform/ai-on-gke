# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

data "google_client_config" "default" {}

data "google_client_openid_userinfo" "identity" {}

locals {
  hostname_suffix             = "endpoints.${data.google_project.environment.project_id}.cloud.goog"
  gateway_manifests_directory = "${path.module}/manifests/ml-team/gateway"
  gateway_name                = "external-https"
  ray_head_service_name       = "ray-cluster-kuberay-head-svc"
  ray_dashboard_endpoint      = "ray-dashboard.${data.kubernetes_namespace_v1.team.metadata[0].name}.mlp.${local.hostname_suffix}"
  ray_dashboard_port          = 8265
  iap_domain                  = var.iap_domain != null ? var.iap_domain : split("@", trimspace(data.google_client_openid_userinfo.identity.email))[1]
  iap_oath_brand              = "projects/${data.google_project.environment.number}/brands/${data.google_project.environment.number}"
}

###############################################################################
# GATEWAY
###############################################################################
resource "google_project_service" "certificatemanager_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "certificatemanager.googleapis.com"
}

resource "google_compute_managed_ssl_certificate" "external_gateway" {
  depends_on = [
    google_project_service.certificatemanager_googleapis_com,
  ]

  name    = "${var.namespace}-external-gateway"
  project = data.google_project.environment.project_id

  managed {
    domains = [local.ray_dashboard_endpoint]
  }
}

resource "google_compute_global_address" "external_gateway_https" {
  depends_on = [
    google_project_service.compute_googleapis_com
  ]

  name    = "${data.kubernetes_namespace_v1.team.metadata[0].name}-external-gateway-https"
  project = data.google_project.environment.project_id
}

resource "google_endpoints_service" "ray_dashboard_https" {
  openapi_config = templatefile(
    "${path.module}/templates/openapi/endpoint.tftpl.yaml",
    {
      endpoint   = local.ray_dashboard_endpoint,
      ip_address = google_compute_global_address.external_gateway_https.address
    }
  )
  project      = data.google_project.environment.project_id
  service_name = local.ray_dashboard_endpoint
}

resource "local_file" "gateway_external_https_yaml" {
  content = templatefile(
    "${path.module}/templates/gateway/gateway-external-https.tftpl.yaml",
    {
      address_name         = google_compute_global_address.external_gateway_https.name,
      gateway_name         = local.gateway_name,
      ssl_certificate_name = google_compute_managed_ssl_certificate.external_gateway.name
    }
  )
  filename = "${local.gateway_manifests_directory}/gateway-external-https.yaml"
}

resource "local_file" "route_ray_dashboard_https_yaml" {
  content = templatefile(
    "${path.module}/templates/gateway/http-route-service.tftpl.yaml",
    {
      gateway_name    = local.gateway_name,
      http_route_name = "ray-dashboard-https",
      hostname        = local.ray_dashboard_endpoint
      service_name    = local.ray_head_service_name
      service_port    = local.ray_dashboard_port
    }
  )
  filename = "${local.gateway_manifests_directory}/route-ray-dashboard-https.yaml"
}

###############################################################################
# IAP
###############################################################################
resource "google_project_service" "iap_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = true
  project                    = data.google_project.environment.project_id
  service                    = "iap.googleapis.com"
}

resource "google_iap_client" "ray_head_client" {
  depends_on = [
    google_project_service.iap_googleapis_com
  ]

  brand        = local.iap_oath_brand
  display_name = "IAP-gkegw-${data.kubernetes_namespace_v1.team.metadata[0].name}-ray-head-dashboard"
}

# TODO: Look at possibly converting to google_iap_web_backend_service_iam_member, but would need the gateway to be created first.
# BACKEND_SERVICE=$(gcloud compute backend-services list --filter="name~'<backend-service>'" --format="value(name)")
resource "google_iap_web_iam_member" "domain_iap_https_resource_accessor" {
  depends_on = [
    google_project_service.iap_googleapis_com
  ]

  project = data.google_project.environment.project_id
  member  = "domain:${local.iap_domain}"
  role    = "roles/iap.httpsResourceAccessor"
}

resource "kubernetes_secret_v1" "ray_head_client" {
  data = {
    secret = google_iap_client.ray_head_client.secret
  }

  metadata {
    name      = "ray-head-client"
    namespace = data.kubernetes_namespace_v1.team.metadata[0].name
  }
}

resource "local_file" "policy_iap_ray_head_yaml" {
  content = templatefile(
    "${path.module}/templates/gateway/gcp-backend-policy-iap-service.tftpl.yaml",
    {
      oauth_client_id          = google_iap_client.ray_head_client.client_id
      oauth_client_secret_name = kubernetes_secret_v1.ray_head_client.metadata[0].name
      policy_name              = "ray-head"
      service_name             = local.ray_head_service_name
    }
  )
  filename = "${local.gateway_manifests_directory}/policy-iap-ray-head.yaml"
}

###############################################################################
# CONFIG SYNC
###############################################################################
resource "local_file" "gateway_kustomization_yaml" {
  content = templatefile(
    "${path.module}/templates/kustomize/kustomization.tftpl.yaml",
    {
      namespace = data.kubernetes_namespace_v1.team.metadata[0].name
      resources = [
        basename(local_file.gateway_external_https_yaml.filename),
        basename(local_file.policy_iap_ray_head_yaml.filename),
        basename(local_file.route_ray_dashboard_https_yaml.filename),
      ]
    }
  )
  filename = "${local.gateway_manifests_directory}/kustomization.yaml"
}

resource "null_resource" "gateway_manifests" {
  depends_on = [
    github_branch.environment,
    google_compute_managed_ssl_certificate.external_gateway,
    google_endpoints_service.ray_dashboard_https,
    kubernetes_secret_v1.ray_head_client,
    module.gke
  ]

  provisioner "local-exec" {
    command = "scripts/gateway_manifests.sh"
    environment = {
      GIT_EMAIL           = self.triggers.github_email
      GIT_REPOSITORY      = self.triggers.git_repository
      GIT_TOKEN           = self.triggers.github_token
      GIT_USERNAME        = self.triggers.github_user
      KUBECONFIG          = self.triggers.kubeconfig
      K8S_NAMESPACE       = self.triggers.namespace
      REPO_SYNC_NAME      = self.triggers.repo_sync_name
      REPO_SYNC_NAMESPACE = self.triggers.repo_sync_namespace
    }
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }

  provisioner "local-exec" {
    command = "scripts/gateway_cleanup.sh"
    environment = {
      GIT_EMAIL           = self.triggers.github_email
      GIT_REPOSITORY      = self.triggers.git_repository
      GIT_TOKEN           = self.triggers.github_token
      GIT_USERNAME        = self.triggers.github_user
      K8S_NAMESPACE       = self.triggers.namespace
      KUBECONFIG          = self.triggers.kubeconfig
      REPO_SYNC_NAME      = self.triggers.repo_sync_name
      REPO_SYNC_NAMESPACE = self.triggers.repo_sync_namespace
    }
    interpreter = ["bash", "-c"]
    when        = destroy
    working_dir = path.module
  }

  triggers = {
    gateway_name   = local.gateway_name
    git_repository = github_repository.acm_repo.full_name
    github_email   = var.github_email
    github_token   = var.github_token
    github_user    = var.github_user
    kubeconfig     = "${local.kubeconfig_dir}/${data.google_project.environment.project_id}_${google_gke_hub_membership.cluster.membership_id}"
    md5_script     = filemd5("${path.module}/scripts/gateway_manifests.sh")
    md5_files = md5(join("", [
      local_file.gateway_external_https_yaml.content_md5,
      local_file.policy_iap_ray_head_yaml.content_md5,
      local_file.route_ray_dashboard_https_yaml.content_md5,
      local_file.gateway_kustomization_yaml.content_md5
    ]))
    namespace           = data.kubernetes_namespace_v1.team.metadata[0].name
    repo_sync_name      = "${var.environment_name}-${data.kubernetes_namespace_v1.team.metadata[0].name}"
    repo_sync_namespace = data.kubernetes_namespace_v1.team.metadata[0].name

  }
}

###############################################################################
# OUTPUT
###############################################################################
output "iap_domain" {
  value = local.iap_domain
}

output "ray_dashboard_url_https" {
  value = "https://${local.ray_dashboard_endpoint}"
}
