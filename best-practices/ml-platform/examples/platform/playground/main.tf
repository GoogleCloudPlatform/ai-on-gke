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
  remove_default_node_pool    = false
  service_account             = google_service_account.cluster.email
  subnet                      = module.create-vpc.subnet-1
  zone                        = "${var.subnet_01_region}-a"
}

module "node_pool_cpu_n2s8" {
  source = "../../../terraform/modules/node-pools"

  depends_on = [
    module.gke
  ]

  autoscaling = {
    location_policy      = "BALANCED"
    total_max_node_count = 32
    total_min_node_count = 1
  }
  cluster_name       = module.gke.cluster_name
  initial_node_count = 1
  location           = var.subnet_01_region
  machine_type       = "n2-standard-8"
  node_pool_name     = "cpu-n2s8"
  project_id         = data.google_project.environment.project_id
  resource_type      = "cpu"
  service_account    = google_service_account.cluster.email
}

module "node_pool_gpu_l4x2_g2s24" {
  source = "../../../terraform/modules/node-pools"

  depends_on = [
    module.gke
  ]

  cluster_name = module.gke.cluster_name
  guest_accelerator = {
    count = 2
    type  = "nvidia-l4"
    gpu_driver_installation_config = {
      gpu_driver_version = var.gpu_driver_version
    }
  }
  location        = var.subnet_01_region
  node_pool_name  = "gpu-l4x2-g2s24"
  project_id      = data.google_project.environment.project_id
  resource_type   = "gpu-l4"
  service_account = google_service_account.cluster.email
  taints          = var.ondemand_taints
}

#
# Removed reservation for cost savings
#

# module "reservation" {
#   source = "../../../terraform/modules/vm-reservations"

#   cluster_name = module.gke.cluster_name
#   project_id   = data.google_project.environment.project_id
#   zone         = "${var.subnet_01_region}-a"
# }

# module "node_pool_gpu_l4x2_g2s24_res" {
#   source = "../../../terraform/modules/node-pools"

#   depends_on = [
#     module.reservation
#   ]

#   cluster_name = module.gke.cluster_name
#   guest_accelerator = {
#     count = 2
#     type  = "nvidia-l4"
#   }
#   location       = var.subnet_01_region
#   node_pool_name = "gpu-l4x2-g2s24-res"
#   project_id     = data.google_project.environment.project_id
#   reservation_affinity = {
#     consume_reservation_type = "SPECIFIC_RESERVATION"
#     key                      = "compute.googleapis.com/reservation-name"
#     values                   = [module.reservation.reservation_name]
#   }
#   resource_type   = "gpu-l4-reservation"
#   service_account = google_service_account.cluster.email
#   taints          = var.reserved_taints
# }

module "node_pool_gpu_l4x2_g2s24_spot" {
  source = "../../../terraform/modules/node-pools"

  depends_on = [
    module.gke
  ]

  cluster_name = module.gke.cluster_name
  guest_accelerator = {
    count = 2
    type  = "nvidia-l4"
    gpu_driver_installation_config = {
      gpu_driver_version = var.gpu_driver_version
    }
  }
  location        = var.subnet_01_region
  node_pool_name  = "gpu-l4x2-g2s24-spot"
  project_id      = data.google_project.environment.project_id
  resource_type   = "gpu-l4-spot"
  service_account = google_service_account.cluster.email
  taints          = var.spot_taints
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

#
# Git Repository
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

#
# Scripts
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
    null_resource.create_git_cred_ns,
    null_resource.create_namespace
  ]

  metadata {
    name = var.namespace
  }
}

resource "null_resource" "create_cluster_yamls" {
  depends_on = [
    google_gke_hub_feature_membership.cluster_configmanagement,
    module.gke,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_cluster_yamls.sh"
    environment = {
      CLUSTER_ENV    = var.environment_name
      CLUSTER_NAME   = module.gke.cluster_name
      GIT_EMAIL      = var.github_email
      GIT_REPOSITORY = local.git_repository
      GIT_TOKEN      = var.github_token
      GIT_USERNAME   = var.github_user
    }
  }

  triggers = {
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/acm-template", "**") : md5("${path.module}/templates/acm-template/${f}")]))
    md5_script = filemd5("${path.module}/scripts/create_cluster_yamls.sh")
  }
}

resource "null_resource" "create_git_cred_cms" {
  depends_on = [
    google_gke_hub_feature_membership.cluster_configmanagement,
    null_resource.connect_gateway_kubeconfig
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_git_cred.sh"
    environment = {
      GIT_EMAIL      = var.github_email
      GIT_REPOSITORY = local.git_repository
      GIT_TOKEN      = var.github_token
      GIT_USERNAME   = var.github_user
      K8S_NAMESPACE  = "config-management-system"
      KUBECONFIG     = "${local.kubeconfig_dir}/${data.google_project.environment.project_id}_${google_gke_hub_membership.cluster.membership_id}"
    }
  }

  triggers = {
    md5_credentials = md5(join("", [var.github_user, var.github_token]))
    md5_script      = filemd5("${path.module}/scripts/create_git_cred.sh")
  }
}

resource "null_resource" "install_kuberay_operator" {
  depends_on = [
    google_gke_hub_feature_membership.cluster_configmanagement,
    module.gke,
    null_resource.create_cluster_yamls,
    null_resource.create_git_cred_cms,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/install_kuberay_operator.sh"
    environment = {
      GIT_EMAIL      = var.github_email
      GIT_REPOSITORY = local.git_repository
      GIT_TOKEN      = var.github_token
      GIT_USERNAME   = var.github_user
      K8S_NAMESPACE  = var.namespace
    }
  }

  triggers = {
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/acm-template/templates/_cluster_template/kuberay", "**") : md5("${path.module}/templates/acm-template/templates/_cluster_template/kuberay/${f}")]))
    md5_script = filemd5("${path.module}/scripts/install_kuberay_operator.sh")
  }
}

locals {
  namespace_default_kubernetes_service_account = "default"
}

resource "google_service_account" "namespace_default" {
  account_id   = "wi-${var.namespace}-${local.namespace_default_kubernetes_service_account}"
  display_name = "${var.namespace}/${local.namespace_default_kubernetes_service_account} workload identity service account"
  project      = data.google_project.environment.project_id
}

resource "google_service_account_iam_member" "namespace_default_iam_workload_identity_user" {
  depends_on = [
    module.gke
  ]

  member             = "serviceAccount:${data.google_project.environment.project_id}.svc.id.goog[${var.namespace}/${local.namespace_default_kubernetes_service_account}]"
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.namespace_default.id
}

resource "null_resource" "create_namespace" {
  depends_on = [
    google_gke_hub_feature_membership.cluster_configmanagement,
    module.gke,
    null_resource.install_kuberay_operator
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_namespace.sh"
    environment = {
      CLUSTER_ENV    = var.environment_name
      CLUSTER_NAME   = module.gke.cluster_name
      GIT_EMAIL      = var.github_email
      GIT_REPOSITORY = local.git_repository
      GIT_TOKEN      = var.github_token
      GIT_USERNAME   = var.github_user
      K8S_NAMESPACE  = self.triggers.namespace
    }
  }

  provisioner "local-exec" {
    command = "scripts/namespace_cleanup.sh"
    environment = {
      GIT_EMAIL           = self.triggers.github_email
      GIT_REPOSITORY      = self.triggers.git_repository
      GIT_TOKEN           = self.triggers.github_token
      GIT_USERNAME        = self.triggers.github_user
      KUBECONFIG          = self.triggers.kubeconfig
      K8S_NAMESPACE       = self.triggers.namespace
      REPO_SYNC_NAME      = self.triggers.repo_sync_name
      REPO_SYNC_NAMESPACE = self.triggers.repo_sync_namespace
      ROOT_SYNC_NAME      = self.triggers.root_sync_name
    }
    when        = destroy
    working_dir = path.module
  }

  triggers = {
    git_repository      = local.git_repository
    github_email        = var.github_email
    github_token        = var.github_token
    github_user         = var.github_user
    kubeconfig          = "${local.kubeconfig_dir}/${data.google_project.environment.project_id}_${google_gke_hub_membership.cluster.membership_id}"
    md5_files           = md5(join("", [for f in fileset("${path.module}/templates/acm-template/templates/_cluster_template/team", "**") : md5("${path.module}/templates/acm-template/templates/_cluster_template/team/${f}")]))
    md5_script          = filemd5("${path.module}/scripts/create_namespace.sh")
    namespace           = var.namespace
    repo_sync_name      = "${var.environment_name}-${var.namespace}"
    repo_sync_namespace = var.namespace
    root_sync_name      = "root-sync"
  }
}

resource "null_resource" "create_git_cred_ns" {
  depends_on = [
    null_resource.connect_gateway_kubeconfig,
    null_resource.create_namespace
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_git_cred.sh"
    environment = {
      GIT_TOKEN     = var.github_token
      GIT_USERNAME  = var.github_user
      K8S_NAMESPACE = var.namespace
      KUBECONFIG    = "${local.kubeconfig_dir}/${data.google_project.environment.project_id}_${google_gke_hub_membership.cluster.membership_id}"
    }
  }

  triggers = {
    md5_credentials = md5(join("", [var.github_user, var.github_token]))
    md5_script      = filemd5("${path.module}/scripts/create_git_cred.sh")
  }
}

locals {
  ray_head_kubernetes_service_account   = "ray-head"
  ray_worker_kubernetes_service_account = "ray-worker"
}

resource "google_service_account" "namespace_ray_head" {
  account_id   = "wi-${var.namespace}-${local.ray_head_kubernetes_service_account}"
  display_name = "${var.namespace}/${local.ray_head_kubernetes_service_account} workload identity service account"
  project      = data.google_project.environment.project_id
}

resource "google_service_account_iam_member" "namespace_ray_head_iam_workload_identity_user" {
  depends_on = [
    module.gke
  ]

  member             = "serviceAccount:${data.google_project.environment.project_id}.svc.id.goog[${var.namespace}/${local.ray_head_kubernetes_service_account}]"
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.namespace_ray_head.id
}

resource "google_service_account" "namespace_ray_worker" {
  account_id   = "wi-${var.namespace}-${local.ray_worker_kubernetes_service_account}"
  display_name = "${var.namespace}/${local.ray_worker_kubernetes_service_account} workload identity service account"
  project      = data.google_project.environment.project_id
}

resource "google_service_account_iam_member" "namespace_ray_worker_iam_workload_identity_user" {
  depends_on = [
    module.gke
  ]

  member             = "serviceAccount:${data.google_project.environment.project_id}.svc.id.goog[${var.namespace}/${local.ray_worker_kubernetes_service_account}]"
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.namespace_ray_worker.id
}

resource "null_resource" "install_ray_cluster" {
  depends_on = [
    google_gke_hub_feature_membership.cluster_configmanagement,
    module.gke,
    null_resource.create_git_cred_ns,
    null_resource.create_namespace
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/install_ray_cluster.sh"
    environment = {
      GIT_EMAIL                     = var.github_email
      GIT_REPOSITORY                = local.git_repository
      GIT_TOKEN                     = var.github_token
      GIT_USERNAME                  = var.github_user
      GOOGLE_SERVICE_ACCOUNT_HEAD   = google_service_account.namespace_ray_head.email
      GOOGLE_SERVICE_ACCOUNT_WORKER = google_service_account.namespace_ray_worker.email
      K8S_NAMESPACE                 = var.namespace
      K8S_SERVICE_ACCOUNT_HEAD      = local.ray_head_kubernetes_service_account
      K8S_SERVICE_ACCOUNT_WORKER    = local.ray_worker_kubernetes_service_account
    }
  }

  triggers = {
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/acm-template/templates/_namespace_template/app", "**") : md5("${path.module}/templates/acm-template/templates/_namespace_template/app/${f}")]))
    md5_script = filemd5("${path.module}/scripts/install_ray_cluster.sh")
  }
}

resource "null_resource" "manage_ray_ns" {
  depends_on = [
    google_gke_hub_feature_membership.cluster_configmanagement,
    module.gke,
    null_resource.create_git_cred_ns,
    null_resource.install_ray_cluster
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/manage_ray_ns.sh"
    environment = {
      GIT_EMAIL      = var.github_email
      GIT_REPOSITORY = local.git_repository
      GIT_TOKEN      = var.github_token
      GIT_USERNAME   = var.github_user
      K8S_NAMESPACE  = var.namespace
    }
  }

  triggers = {
    md5_script = filemd5("${path.module}/scripts/manage_ray_ns.sh")
  }
}

###############################################################################
# OUTPUT
###############################################################################
output "configsync_repository" {
  value = local.configsync_repository.html_url
}

output "git_repository" {
  value = local.git_repository
}
