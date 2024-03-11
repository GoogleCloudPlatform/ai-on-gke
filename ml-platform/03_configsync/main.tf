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

data "terraform_remote_state" "gke-clusters" {
  backend = "gcs"
  config = {
    bucket = var.lookup_state_bucket
    prefix = "02_gke"
  }
}

locals {
  parsed_gke_info = data.terraform_remote_state.gke-clusters.outputs.gke_cluster
  project_id_list = [for k, v in "${data.terraform_remote_state.gke-clusters.outputs.gke_cluster}" : v.gke_project_id]
}

//resource "google_gke_hub_feature" "configmanagement_acm_feature" {
//  count    = length(distinct(local.project_id_list))
//  name     = "configmanagement"
//  project  = distinct(local.project_id_list)[count.index]
//  location = "global"
//  provider = google-beta
//}

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
      "labels", "description"
    ]
  }
  #depends_on = [ google_gke_hub_feature.configmanagement_acm_feature ]
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
//Create a branch for each env
resource "github_branch" "branch" {
  for_each   = local.parsed_gke_info
  repository = split("/", github_repository.acm_repo.full_name)[1]
  branch     = each.key
  depends_on = [github_repository.acm_repo]
}
//Set default branch as the lowest env
resource "github_branch_default" "default_branch" {
  repository = split("/", github_repository.acm_repo.full_name)[1]
  branch     = tostring(keys(local.parsed_gke_info)[0])
  #rename     = true
  depends_on = [github_branch.branch]
}
#Protect branches other than the default branch
resource "github_branch_protection_v3" "branch_protection" {
  for_each   = local.parsed_gke_info
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
    version = "1.17.0"
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

  provisioner "local-exec" {
    command = "${path.module}/create_cluster_yamls.sh ${var.github_org} ${github_repository.acm_repo.full_name} ${var.github_user} ${var.github_email} ${each.value["env"]} ${each.value["cluster_name"]} ${index(keys(local.parsed_gke_info), each.key)}"
  }

  #depends_on = [
  #  google_gke_hub_feature.configmanagement_acm_feature
  # ]
}
