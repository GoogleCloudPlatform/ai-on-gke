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

locals {
  configsync_repository = module.configsync_repository
  # https://github.com/hashicorp/terraform-provider-google/issues/13325
  connect_gateway_host_url = "https://connectgateway.googleapis.com/v1/projects/${data.google_project.environment.number}/locations/global/gkeMemberships/${module.gke.cluster_name}"
  git_repository           = replace(local.configsync_repository.html_url, "/https*:\\/\\//", "")
  kubeconfig_dir           = abspath("${path.module}/kubeconfig")
}

#
# Project
##########################################################################
data "google_project" "environment" {
  project_id = var.environment_project_id
}

resource "google_project_service" "anthos_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "anthos.googleapis.com"
}

resource "google_project_service" "anthosconfigmanagement_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "anthosconfigmanagement.googleapis.com"
}

resource "google_project_service" "cloudresourcemanager_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "compute_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "compute.googleapis.com"
}

resource "google_project_service" "connectgateway_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "connectgateway.googleapis.com"
}

resource "google_project_service" "container_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "container.googleapis.com"
}

resource "google_project_service" "containerfilesystem_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "containerfilesystem.googleapis.com"
}

resource "google_project_service" "containersecurity_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "containersecurity.googleapis.com"
}

resource "google_project_service" "gkeconnect_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "gkeconnect.googleapis.com"
}

resource "google_project_service" "gkehub_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "gkehub.googleapis.com"
}

resource "google_project_service" "iam_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "iam.googleapis.com"
}

resource "google_project_service" "serviceusage_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "serviceusage.googleapis.com"
}

#
# Networking
##########################################################################
module "create-vpc" {
  source = "../../../terraform/modules/network"

  depends_on = [
    google_project_service.compute_googleapis_com
  ]

  network_name     = format("%s-%s", var.network_name, var.environment_name)
  project_id       = data.google_project.environment.project_id
  routing_mode     = var.routing_mode
  subnet_01_ip     = var.subnet_01_ip
  subnet_01_name   = format("%s-%s", var.subnet_01_name, var.environment_name)
  subnet_01_region = var.subnet_01_region
}

module "cloud-nat" {
  source = "../../../terraform/modules/cloud-nat"

  create_router = true
  name          = format("%s-%s", "nat-for-acm", var.environment_name)
  network       = module.create-vpc.vpc
  project_id    = data.google_project.environment.project_id
  region        = split("/", module.create-vpc.subnet-1)[3]
  router        = format("%s-%s", "router-for-acm", var.environment_name)
}

#
# GKE
##########################################################################
resource "google_gke_hub_feature" "configmanagement" {
  depends_on = [
    google_project_service.anthos_googleapis_com,
    google_project_service.anthosconfigmanagement_googleapis_com,
    google_project_service.compute_googleapis_com,
    google_project_service.gkeconnect_googleapis_com,
    google_project_service.gkehub_googleapis_com,
    local.configsync_repository
  ]

  location = "global"
  name     = "configmanagement"
  project  = data.google_project.environment.project_id
}

# Create dedicated service account for node pools
resource "google_service_account" "cluster" {
  project      = data.google_project.environment.project_id
  account_id   = "vm-${var.cluster_name}-${var.environment_name}"
  display_name = "${var.cluster_name}-${var.environment_name} Service Account"
  description  = "Terraform-managed service account for cluster ${var.cluster_name}-${var.environment_name}"
}

# Apply minimal roles to nodepool SA
# https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa
locals {
  cluster_sa_roles = [
    "roles/monitoring.viewer",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/autoscaling.metricsWriter",
    "roles/artifactregistry.reader",
    "roles/serviceusage.serviceUsageConsumer"
  ]
}

# Bind minimum role list + additional roles to nodepool SA on project
resource "google_project_iam_member" "cluster_sa" {
  for_each = toset(local.cluster_sa_roles)
  project  = data.google_project.environment.project_id
  member   = google_service_account.cluster.member
  role     = each.value
}

module "gke" {
  source = "../../../terraform/modules/cluster"

  depends_on = [
    google_gke_hub_feature.configmanagement,
    google_project_service.compute_googleapis_com,
    google_project_service.container_googleapis_com,
    module.cloud-nat
  ]

  cluster_name                = format("%s-%s", var.cluster_name, var.environment_name)
  env                         = var.environment_name
  initial_node_count          = 1
  machine_type                = "e2-standard-4"
  master_auth_networks_ipcidr = var.subnet_01_ip
  network                     = module.create-vpc.vpc
  project_id                  = data.google_project.environment.project_id
  region                      = var.subnet_01_region
  release_channel             = "RAPID"
  remove_default_node_pool    = true
  service_account             = google_service_account.cluster.email
  subnet                      = module.create-vpc.subnet-1
  zone                        = "${var.subnet_01_region}-a"
}

resource "google_gke_hub_membership" "cluster" {
  depends_on = [
    google_gke_hub_feature.configmanagement,
    google_project_service.gkeconnect_googleapis_com,
    google_project_service.gkehub_googleapis_com
  ]

  membership_id = module.gke.cluster_name
  project       = data.google_project.environment.project_id

  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${module.gke.cluster_id}"
    }
  }
}

resource "google_gke_hub_feature_membership" "cluster_configmanagement" {
  depends_on = [
    google_container_node_pool.system,
    google_project_service.anthos_googleapis_com,
    google_project_service.anthosconfigmanagement_googleapis_com,
    google_project_service.gkeconnect_googleapis_com,
    google_project_service.gkehub_googleapis_com,
    local.configsync_repository,
    module.cloud-nat
  ]

  feature    = "configmanagement"
  location   = "global"
  membership = google_gke_hub_membership.cluster.membership_id
  project    = data.google_project.environment.project_id

  configmanagement {
    version = var.config_management_version

    config_sync {
      source_format = "unstructured"

      git {
        policy_dir  = "manifests/clusters"
        secret_type = "token"
        sync_branch = local.configsync_repository.default_branch
        sync_repo   = local.configsync_repository.http_clone_url
      }
    }

    policy_controller {
      enabled                    = true
      referential_rules_enabled  = true
      template_library_installed = true

    }
  }
}



# GIT REPOSITORY
##########################################################################
module "configsync_repository" {
  source = "../../../terraform/modules/github_repository"

  branches = {
    default = var.environment_name
    names   = ["main", var.environment_name]
  }
  description = "Google Cloud Config Sync repository"
  name        = var.configsync_repo_name
  owner       = var.github_org
  token       = var.github_token
}



# KUBERNETES
##########################################################################
provider "kubernetes" {
  host  = local.connect_gateway_host_url
  token = data.google_client_config.default.access_token
}

resource "null_resource" "connect_gateway_kubeconfig" {
  provisioner "local-exec" {
    command     = <<EOT
KUBECONFIG="${self.triggers.project_id}_${self.triggers.membership_id}" \
gcloud container fleet memberships get-credentials ${self.triggers.membership_id} \
--project ${self.triggers.project_id}
    EOT
    interpreter = ["bash", "-c"]
    working_dir = self.triggers.kubeconfig_dir
  }

  provisioner "local-exec" {
    command     = "rm -f ${self.triggers.project_id}_${self.triggers.membership_id}"
    when        = destroy
    interpreter = ["bash", "-c"]
    working_dir = self.triggers.kubeconfig_dir
  }

  triggers = {
    kubeconfig_dir = local.kubeconfig_dir
    membership_id  = google_gke_hub_membership.cluster.membership_id
    project_id     = data.google_project.environment.project_id
  }
}

data "kubernetes_namespace_v1" "team" {
  depends_on = [
    null_resource.git_cred_secret_ns,
    null_resource.namespace_manifests
  ]

  metadata {
    name = var.namespace
  }
}



# OUTPUT
###############################################################################
output "configsync_repository" {
  value = local.configsync_repository.html_url
}

output "git_repository" {
  value = local.git_repository
}
