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
  parsed_project_id                   = var.create_projects == 0 ? var.project_id : { for k, v in "${module.gcp-project.project_ids}" : k => v.project_id }
  parsed_gke_info                     = module.gke
  parsed_gke_info_without_default_env = { for k, v in "${local.parsed_gke_info}" : k => v if k != var.default_env }
  project_id_list                     = [for k, v in "${module.gke}" : v.gke_project_id]
  gke_project_map                     = { for k, v in "${module.gke}" : v.cluster_name => v.gke_project_id }
}

#TODO: Add a validation that the value if default_env must be one of the values in env list
module "gcp-project" {
  count           = var.create_projects
  source          = "./modules/projects"
  org_id          = var.org_id
  folder_id       = var.folder_id
  env             = var.env
  billing_account = var.billing_account
  project_name    = var.project_name
}

resource "google_project_service" "containerfilesystem_googleapis_com" {
  for_each                   = local.parsed_project_id
  project                    = each.value
  service                    = "containerfilesystem.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
  depends_on                 = [module.gcp-project]
}

resource "google_project_service" "project_services-cr" {
  for_each                   = local.parsed_project_id
  project                    = each.value
  service                    = "cloudresourcemanager.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
  depends_on                 = [module.gcp-project]
}

resource "google_project_service" "project_services-an" {
  for_each                   = local.parsed_project_id
  project                    = each.value
  service                    = "anthos.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
  depends_on                 = [module.gcp-project, google_project_service.project_services-cr]
}

resource "google_project_service" "project_services-anc" {
  for_each                   = local.parsed_project_id
  project                    = each.value
  service                    = "anthosconfigmanagement.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
  depends_on                 = [module.gcp-project, google_project_service.project_services-cr]
}

resource "google_project_service" "project_services-con" {
  for_each                   = local.parsed_project_id
  project                    = each.value
  service                    = "container.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
  depends_on                 = [module.gcp-project, google_project_service.project_services-cr]
}

resource "google_project_service" "project_services-com" {
  for_each                   = local.parsed_project_id
  project                    = each.value
  service                    = "compute.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
  depends_on                 = [module.gcp-project, google_project_service.project_services-cr]
}

resource "google_project_service" "project_services-gkecon" {
  for_each                   = local.parsed_project_id
  project                    = each.value
  service                    = "gkeconnect.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
  depends_on                 = [module.gcp-project, google_project_service.project_services-cr]
}

resource "google_project_service" "project_services-gkeh" {
  for_each                   = local.parsed_project_id
  project                    = each.value
  service                    = "gkehub.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
  depends_on                 = [module.gcp-project, google_project_service.project_services-cr]
}

resource "google_project_service" "project_services-iam" {
  for_each                   = local.parsed_project_id
  project                    = each.value
  service                    = "iam.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
  depends_on                 = [module.gcp-project, google_project_service.project_services-cr]
}

resource "google_project_service" "project_services-gate" {
  for_each                   = local.parsed_project_id
  project                    = each.value
  service                    = "connectgateway.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
  depends_on                 = [module.gcp-project, google_project_service.project_services-cr]
}

module "create-vpc" {
  for_each         = local.parsed_project_id
  source           = "./modules/network"
  project_id       = each.value
  network_name     = format("%s-%s", var.network_name, each.key)
  routing_mode     = var.routing_mode
  subnet_01_name   = format("%s-%s", var.subnet_01_name, each.key)
  subnet_01_ip     = var.subnet_01_ip
  subnet_01_region = var.subnet_01_region
  subnet_02_name   = format("%s-%s", var.subnet_02_name, each.key)
  subnet_02_ip     = var.subnet_02_ip
  subnet_02_region = var.subnet_02_region

  depends_on = [
    module.gcp-project,
    google_project_service.project_services-com
  ]
}

resource "google_gke_hub_feature" "configmanagement_acm_feature" {
  count    = length(distinct(values(local.parsed_project_id)))
  name     = "configmanagement"
  project  = distinct(values(local.parsed_project_id))[count.index]
  location = "global"
  provider = google-beta

  depends_on = [
    google_project_service.project_services-gkeh,
    google_project_service.project_services-anc,
    google_project_service.project_services-an,
    google_project_service.project_services-com,
    google_project_service.project_services-gkecon
  ]
}

module "gke" {
  for_each                    = local.parsed_project_id
  source                      = "./modules/cluster"
  cluster_name                = format("%s-%s", var.cluster_name, each.key)
  network                     = module.create-vpc[each.key].vpc
  subnet                      = module.create-vpc[each.key].subnet-1
  project_id                  = each.value
  region                      = var.subnet_01_region
  zone                        = "${var.subnet_01_region}-a"
  master_auth_networks_ipcidr = var.subnet_01_ip
  depends_on                  = [google_gke_hub_feature.configmanagement_acm_feature, google_project_service.project_services-con, google_project_service.project_services-com]
  env                         = each.key
}

module "reservation" {
  for_each     = local.parsed_project_id
  source       = "./modules/vm-reservations"
  cluster_name = module.gke[each.key].cluster_name
  zone         = "${var.subnet_01_region}-a"
  project_id   = each.value
  depends_on   = [module.gke]
}

module "node_pool-reserved" {
  for_each         = local.parsed_project_id
  source           = "./modules/node-pools"
  node_pool_name   = "reservation"
  project_id       = each.value
  cluster_name     = module.gke[each.key].cluster_name
  region           = var.subnet_01_region
  taints           = var.reserved_taints
  resource_type    = "reservation"
  reservation_name = module.reservation[each.key].reservation_name
  depends_on       = [module.reservation]
}

module "node_pool-ondemand" {
  for_each       = local.parsed_project_id
  source         = "./modules/node-pools"
  node_pool_name = "ondemand"
  project_id     = each.value
  cluster_name   = module.gke[each.key].cluster_name
  region         = var.subnet_01_region
  taints         = var.ondemand_taints
  resource_type  = "ondemand"
  depends_on     = [module.gke]
}

module "node_pool-spot" {
  for_each       = local.parsed_project_id
  source         = "./modules/node-pools"
  node_pool_name = "spot"
  project_id     = each.value
  cluster_name   = module.gke[each.key].cluster_name
  region         = var.subnet_01_region
  taints         = var.spot_taints
  resource_type  = "spot"
  depends_on     = [module.gke]
}

module "cloud-nat" {
  for_each      = local.parsed_project_id
  source        = "./modules/cloud-nat"
  project_id    = each.value
  region        = split("/", module.create-vpc[each.key].subnet-1)[3]
  name          = format("%s-%s", "nat-for-acm", each.key)
  network       = module.create-vpc[each.key].vpc
  create_router = true
  router        = format("%s-%s", "router-for-acm", each.key)
  depends_on    = [module.create-vpc, google_project_service.project_services-com]
}

resource "google_gke_hub_membership" "membership" {
  provider      = google-beta
  for_each      = local.parsed_gke_info
  project       = each.value["gke_project_id"]
  membership_id = each.value["cluster_name"]
  endpoint {
    gke_cluster {
      resource_link = format("%s/%s", "//container.googleapis.com", each.value["cluster_id"])
    }
  }

  lifecycle {
    ignore_changes = [
      labels
    ]
  }

  depends_on = [
    google_gke_hub_feature.configmanagement_acm_feature,
    google_project_service.project_services-gkeh,
    google_project_service.project_services-gkecon
  ]
}

resource "github_repository" "acm_repo" {
  name         = var.configsync_repo_name
  description  = "Repo for Config Sync"
  visibility   = "private"
  has_issues   = false
  has_projects = false
  has_wiki     = false

  allow_merge_commit     = true
  allow_squash_merge     = true
  allow_rebase_merge     = true
  delete_branch_on_merge = false
  auto_init              = true
  vulnerability_alerts   = true
}

resource "github_branch" "branch" {
  for_each   = local.parsed_gke_info
  repository = split("/", github_repository.acm_repo.full_name)[1]
  branch     = each.key
  depends_on = [github_repository.acm_repo]
}

resource "github_branch_default" "default_branch" {
  repository = split("/", github_repository.acm_repo.full_name)[1]
  branch     = var.default_env
  depends_on = [github_branch.branch]
}

resource "github_branch_protection_v3" "branch_protection" {
  for_each   = length(keys(local.parsed_project_id)) > 1 ? local.parsed_gke_info_without_default_env : {}
  repository = split("/", github_repository.acm_repo.full_name)[1]
  branch     = each.key
  required_pull_request_reviews {
    required_approving_review_count = 1
    require_code_owner_reviews      = true
  }
  restrictions {
  }

  depends_on = [github_branch.branch]
}

resource "google_gke_hub_feature_membership" "feature_member" {
  provider   = google-beta
  for_each   = local.parsed_gke_info
  project    = each.value["gke_project_id"]
  location   = "global"
  feature    = "configmanagement"
  membership = google_gke_hub_membership.membership[each.key].membership_id
  configmanagement {
    version = var.config_management_version
    config_sync {
      source_format = "unstructured"
      git {
        sync_repo   = "https://github.com/${github_repository.acm_repo.full_name}.git"
        sync_branch = each.value["env"]
        policy_dir  = "manifests/clusters"
        secret_type = "token"
      }
    }
    policy_controller {
      enabled                    = true
      template_library_installed = true
      referential_rules_enabled  = true
    }
  }

  depends_on = [
    google_project_service.project_services-gkecon,
    google_project_service.project_services-gkeh,
    google_project_service.project_services-an,
    google_project_service.project_services-anc
  ]
}

resource "null_resource" "create_cluster_yamls" {
  for_each = local.parsed_gke_info
  triggers = {
    md5_script = filemd5("${path.module}/scripts/create_cluster_yamls.sh")
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/acm-template", "**") : md5("${path.module}/templates/acm-template/${f}")]))
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_cluster_yamls.sh ${var.github_org} ${github_repository.acm_repo.full_name} ${var.github_user} ${var.github_email} ${each.value["env"]} ${each.value["cluster_name"]} ${index(keys(local.parsed_gke_info), each.key)}"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  depends_on = [google_gke_hub_feature_membership.feature_member]
}

resource "null_resource" "create_git_cred_cms" {
  for_each = var.secret_for_rootsync == 1 ? local.gke_project_map : {}
  triggers = {
    md5_script      = filemd5("${path.module}/scripts/create_git_cred.sh")
    md5_credentials = md5(join("", [var.github_user, var.github_token]))
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_git_cred.sh ${each.key} ${each.value} ${var.github_user} config-management-system ${index(keys(local.gke_project_map), each.key)}"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  depends_on = [
    google_gke_hub_feature_membership.feature_member,
    module.gke,
    module.node_pool-reserved,
    module.node_pool-ondemand,
    module.node_pool-spot,
    module.cloud-nat
  ]
}

resource "null_resource" "install_kuberay_operator" {
  count = var.install_kuberay
  triggers = {
    md5_script = filemd5("${path.module}/scripts/install_kuberay_operator.sh")
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/acm-template/templates/_cluster_template/kuberay", "**") : md5("${path.module}/templates/acm-template/templates/_cluster_template/kuberay/${f}")]))
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/install_kuberay_operator.sh ${github_repository.acm_repo.full_name} ${var.github_email} ${var.github_org} ${var.github_user}"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  depends_on = [
    google_gke_hub_feature_membership.feature_member,
    null_resource.create_git_cred_cms
  ]
}

resource "google_service_account" "namespace_default" {
  account_id   = "wi-${var.namespace}-default"
  display_name = "${var.namespace} Default Workload Identity Service Account"
  project      = local.parsed_project_id[var.default_env]
}

resource "google_service_account_iam_member" "wi_cymbal_bank_backend_workload_identity_user" {
  member             = "serviceAccount:${local.parsed_project_id[var.default_env]}.svc.id.goog[${var.namespace}/${var.namespace}-default]"
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.namespace_default.id
}

resource "null_resource" "create_namespace" {
  count = var.create_namespace
  triggers = {
    md5_script = filemd5("${path.module}/scripts/create_namespace.sh")
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/acm-template/templates/_cluster_template/team", "**") : md5("${path.module}/templates/acm-template/templates/_cluster_template/team/${f}")]))
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_namespace.sh ${github_repository.acm_repo.full_name} ${var.github_email} ${var.github_org} ${var.github_user} ${var.namespace} ${var.default_env}"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  depends_on = [
    google_gke_hub_feature_membership.feature_member,
    null_resource.install_kuberay_operator
  ]
}

resource "null_resource" "create_git_cred_ns" {
  count = var.create_namespace
  triggers = {
    md5_script      = filemd5("${path.module}/scripts/create_git_cred.sh")
    md5_credentials = md5(join("", [var.github_user, var.github_token]))
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_git_cred.sh ${local.parsed_gke_info[var.default_env].cluster_name} ${local.parsed_gke_info[var.default_env].gke_project_id} ${var.github_user} ${var.namespace}"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  depends_on = [
    google_gke_hub_feature_membership.feature_member,
    null_resource.create_namespace
  ]
}

resource "null_resource" "install_ray_cluster" {
  count = var.install_ray_in_ns
  triggers = {
    md5_script = filemd5("${path.module}/scripts/install_ray_cluster.sh")
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/acm-template//templates/_namespace_template/app", "**") : md5("${path.module}/templates/acm-template//templates/_namespace_template/app/${f}")]))
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/install_ray_cluster.sh ${github_repository.acm_repo.full_name} ${var.github_email} ${var.github_org} ${var.github_user} ${var.namespace} ${google_service_account.namespace_default.email}"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  depends_on = [
    google_gke_hub_feature_membership.feature_member,
    null_resource.create_git_cred_ns
  ]
}

resource "null_resource" "manage_ray_ns" {
  count = var.install_ray_in_ns
  triggers = {
    md5_script = filemd5("${path.module}/scripts/manage_ray_ns.sh")
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/manage_ray_ns.sh ${github_repository.acm_repo.full_name} ${var.github_email} ${var.github_org} ${var.github_user} ${var.namespace}"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  depends_on = [
    google_gke_hub_feature_membership.feature_member,
    null_resource.create_git_cred_ns,
    null_resource.install_ray_cluster
  ]
}
