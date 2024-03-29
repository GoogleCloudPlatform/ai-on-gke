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

#
# Project
##########################################################################
data "google_project" "environment" {
  project_id = var.environment_project_id
}

resource "google_project_service" "containerfilesystem_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "containerfilesystem.googleapis.com"
}

resource "google_project_service" "serviceusage_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "serviceusage.googleapis.com"
}

resource "google_project_service" "project_services-cr" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "project_services-an" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "anthos.googleapis.com"
}

resource "google_project_service" "project_services-anc" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "anthosconfigmanagement.googleapis.com"
}

resource "google_project_service" "project_services-con" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "container.googleapis.com"
}

resource "google_project_service" "project_services-com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "compute.googleapis.com"
}

resource "google_project_service" "project_services-gkecon" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "gkeconnect.googleapis.com"
}

resource "google_project_service" "project_services-gkeh" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "gkehub.googleapis.com"
}

resource "google_project_service" "project_services-iam" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "iam.googleapis.com"
}

resource "google_project_service" "project_services-gate" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "connectgateway.googleapis.com"
}

#
# Networking
##########################################################################
module "create-vpc" {
  source = "../../../terraform/modules/network"

  depends_on = [
    google_project_service.project_services-com
  ]

  network_name     = format("%s-%s", var.network_name, var.environment_name)
  project_id       = data.google_project.environment.project_id
  routing_mode     = var.routing_mode
  subnet_01_ip     = var.subnet_01_ip
  subnet_01_name   = format("%s-%s", var.subnet_01_name, var.environment_name)
  subnet_01_region = var.subnet_01_region
  subnet_02_ip     = var.subnet_02_ip
  subnet_02_name   = format("%s-%s", var.subnet_02_name, var.environment_name)
  subnet_02_region = var.subnet_02_region
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
resource "google_gke_hub_feature" "configmanagement_acm_feature" {
  depends_on = [
    google_project_service.project_services-gkeh,
    google_project_service.project_services-anc,
    google_project_service.project_services-an,
    google_project_service.project_services-com,
    google_project_service.project_services-gkecon
  ]

  location = "global"
  name     = "configmanagement"
  project  = data.google_project.environment.project_id
}

module "gke" {
  source = "../../../terraform/modules/cluster"

  depends_on = [
    google_gke_hub_feature.configmanagement_acm_feature,
    google_project_service.project_services-con,
    google_project_service.project_services-com
  ]

  cluster_name                = format("%s-%s", var.cluster_name, var.environment_name)
  env                         = var.environment_name
  initial_node_count          = 1
  machine_type                = "n2-standard-8"
  master_auth_networks_ipcidr = var.subnet_01_ip
  network                     = module.create-vpc.vpc
  project_id                  = data.google_project.environment.project_id
  region                      = var.subnet_01_region
  remove_default_node_pool    = false
  subnet                      = module.create-vpc.subnet-1
  zone                        = "${var.subnet_01_region}-a"
}

module "reservation" {
  source = "../../../terraform/modules/vm-reservations"

  cluster_name = module.gke.cluster_name
  project_id   = data.google_project.environment.project_id
  zone         = "${var.subnet_01_region}-a"
}

module "node_pool-reserved" {
  source = "../../../terraform/modules/node-pools"

  depends_on = [
    module.reservation
  ]

  cluster_name     = module.gke.cluster_name
  node_pool_name   = "reservation"
  project_id       = data.google_project.environment.project_id
  region           = var.subnet_01_region
  reservation_name = module.reservation.reservation_name
  resource_type    = "reservation"
  taints           = var.reserved_taints
}

module "node_pool-ondemand" {
  source = "../../../terraform/modules/node-pools"

  depends_on = [
    module.gke
  ]

  cluster_name   = module.gke.cluster_name
  node_pool_name = "ondemand"
  project_id     = data.google_project.environment.project_id
  region         = var.subnet_01_region
  resource_type  = "ondemand"
  taints         = var.ondemand_taints
}

module "node_pool-spot" {
  source = "../../../terraform/modules/node-pools"

  depends_on = [
    module.gke
  ]

  cluster_name   = module.gke.cluster_name
  node_pool_name = "spot"
  project_id     = data.google_project.environment.project_id
  region         = var.subnet_01_region
  resource_type  = "spot"
  taints         = var.spot_taints
}

resource "google_gke_hub_membership" "membership" {
  depends_on = [
    google_gke_hub_feature.configmanagement_acm_feature,
    google_project_service.project_services-gkeh,
    google_project_service.project_services-gkecon
  ]

  membership_id = module.gke.cluster_name
  project       = data.google_project.environment.project_id

  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${module.gke.cluster_id}"
    }
  }
}

resource "google_gke_hub_feature_membership" "feature_member" {
  depends_on = [
    google_project_service.project_services-gkecon,
    google_project_service.project_services-gkeh,
    google_project_service.project_services-an,
    google_project_service.project_services-anc
  ]

  feature    = "configmanagement"
  location   = "global"
  membership = google_gke_hub_membership.membership.membership_id
  project    = data.google_project.environment.project_id

  configmanagement {
    version = var.config_management_version

    config_sync {
      source_format = "unstructured"

      git {
        policy_dir  = "manifests/clusters"
        secret_type = "token"
        sync_branch = github_branch.environment.branch
        sync_repo   = github_repository.acm_repo.http_clone_url
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
# data "github_organization" "default" {
#   name = var.github_org
# }

resource "github_repository" "acm_repo" {
  # depends_on = [
  #   data.github_organization.default
  #  ]

  allow_merge_commit     = true
  allow_rebase_merge     = true
  allow_squash_merge     = true
  auto_init              = true
  delete_branch_on_merge = false
  description            = "Repo for Config Sync"
  has_issues             = false
  has_projects           = false
  has_wiki               = false
  name                   = var.configsync_repo_name
  visibility             = "private"
  vulnerability_alerts   = true
}

resource "github_branch" "environment" {
  branch     = var.environment_name
  repository = github_repository.acm_repo.name
}

resource "github_branch_default" "environment" {
  branch     = github_branch.environment.branch
  repository = github_repository.acm_repo.name
}

resource "github_branch_protection_v3" "environment" {
  repository = github_repository.acm_repo.name
  branch     = github_branch.environment.branch

  required_pull_request_reviews {
    require_code_owner_reviews      = true
    required_approving_review_count = 1
  }

  restrictions {
  }
}

#
# Scripts
##########################################################################
resource "null_resource" "create_cluster_yamls" {
  depends_on = [
    google_gke_hub_feature_membership.feature_member
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_cluster_yamls.sh ${var.github_org} ${github_repository.acm_repo.full_name} ${var.github_user} ${var.github_email} ${var.environment_name} ${module.gke.cluster_name}"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  triggers = {
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/acm-template", "**") : md5("${path.module}/templates/acm-template/${f}")]))
    md5_script = filemd5("${path.module}/scripts/create_cluster_yamls.sh")
  }
}

resource "null_resource" "create_git_cred_cms" {
  depends_on = [
    google_gke_hub_feature_membership.feature_member,
    module.gke,
    module.node_pool-reserved,
    module.node_pool-ondemand,
    module.node_pool-spot,
    module.cloud-nat
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_git_cred.sh ${module.gke.cluster_name} ${data.google_project.environment.project_id} ${var.github_user} config-management-system"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  triggers = {
    md5_credentials = md5(join("", [var.github_user, var.github_token]))
    md5_script      = filemd5("${path.module}/scripts/create_git_cred.sh")
  }
}

resource "null_resource" "install_kuberay_operator" {
  depends_on = [
    google_gke_hub_feature_membership.feature_member,
    null_resource.create_git_cred_cms
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/install_kuberay_operator.sh ${github_repository.acm_repo.full_name} ${var.github_email} ${var.github_org} ${var.github_user}"
    environment = {
      GIT_TOKEN = var.github_token
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
    google_gke_hub_feature_membership.feature_member,
    null_resource.install_kuberay_operator
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_namespace.sh ${github_repository.acm_repo.full_name} ${var.github_email} ${var.github_org} ${var.github_user} ${var.namespace} ${var.environment_name}"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  triggers = {
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/acm-template/templates/_cluster_template/team", "**") : md5("${path.module}/templates/acm-template/templates/_cluster_template/team/${f}")]))
    md5_script = filemd5("${path.module}/scripts/create_namespace.sh")
  }
}

resource "null_resource" "create_git_cred_ns" {
  depends_on = [
    google_gke_hub_feature_membership.feature_member,
    null_resource.create_namespace
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_git_cred.sh ${module.gke.cluster_name} ${module.gke.gke_project_id} ${var.github_user} ${var.namespace}"
    environment = {
      GIT_TOKEN = var.github_token
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
    google_gke_hub_feature_membership.feature_member,
    null_resource.create_git_cred_ns
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/install_ray_cluster.sh ${github_repository.acm_repo.full_name} ${var.github_email} ${var.github_org} ${var.github_user} ${var.namespace} ${google_service_account.namespace_ray_head.email} ${local.ray_head_kubernetes_service_account} ${google_service_account.namespace_ray_worker.email} ${local.ray_worker_kubernetes_service_account}"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  triggers = {
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/acm-template/templates/_namespace_template/app", "**") : md5("${path.module}/templates/acm-template/templates/_namespace_template/app/${f}")]))
    md5_script = filemd5("${path.module}/scripts/install_ray_cluster.sh")
  }
}

resource "null_resource" "manage_ray_ns" {
  depends_on = [
    google_gke_hub_feature_membership.feature_member,
    null_resource.create_git_cred_ns,
    null_resource.install_ray_cluster
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/manage_ray_ns.sh ${github_repository.acm_repo.full_name} ${var.github_email} ${var.github_org} ${var.github_user} ${var.namespace}"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  triggers = {
    md5_script = filemd5("${path.module}/scripts/manage_ray_ns.sh")
  }
}
