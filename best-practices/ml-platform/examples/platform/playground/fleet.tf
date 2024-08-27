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
# Removing to all for multiple environments in the same project
#
# resource "google_gke_hub_feature" "configmanagement" {
#   depends_on = [
#     google_project_service.anthos_googleapis_com,
#     google_project_service.anthosconfigmanagement_googleapis_com,
#     google_project_service.compute_googleapis_com,
#     google_project_service.gkeconnect_googleapis_com,
#     google_project_service.gkehub_googleapis_com,
#     local.configsync_repository
#   ]

#   location = "global"
#   name     = "configmanagement"
#   project  = data.google_project.environment.project_id
# }

resource "null_resource" "gke_hub_feature_configmanagement" {
  depends_on = [
    google_project_service.anthos_googleapis_com,
    google_project_service.anthosconfigmanagement_googleapis_com,
    google_project_service.compute_googleapis_com,
    google_project_service.gkeconnect_googleapis_com,
    google_project_service.gkehub_googleapis_com,
    local.configsync_repository
  ]

  provisioner "local-exec" {
    command = "gcloud beta container fleet config-management enable --project ${var.environment_project_id}"
  }
}

resource "google_gke_hub_membership" "cluster" {
  depends_on = [
    google_gke_hub_membership.cluster,
    google_project_service.gkeconnect_googleapis_com,
    google_project_service.gkehub_googleapis_com,
  ]

  membership_id = google_container_cluster.mlp.name
  project       = data.google_project.environment.project_id

  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.mlp.id}"
    }
  }
}

resource "google_gke_hub_feature_membership" "cluster_configmanagement" {
  depends_on = [
    google_container_cluster.mlp,
    #google_gke_hub_feature" "configmanagement,
    google_project_service.anthos_googleapis_com,
    google_project_service.anthosconfigmanagement_googleapis_com,
    google_project_service.gkeconnect_googleapis_com,
    google_project_service.gkehub_googleapis_com,
    local.configsync_repository,
    module.cloud-nat,
    null_resource.gke_hub_feature_configmanagement
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
