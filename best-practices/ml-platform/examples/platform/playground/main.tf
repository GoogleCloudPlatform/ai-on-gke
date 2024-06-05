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
  connect_gateway_host_url = "https://connectgateway.googleapis.com/v1/projects/${data.google_project.environment.number}/locations/global/gkeMemberships/${google_container_cluster.mlp.name}"
  git_repository           = replace(local.configsync_repository.html_url, "/https*:\\/\\//", "")
  kubeconfig_dir           = abspath("${path.module}/kubeconfig")
}

# FLEET
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

resource "google_gke_hub_membership" "cluster" {
  depends_on = [
    google_gke_hub_feature.configmanagement,
    google_project_service.gkeconnect_googleapis_com,
    google_project_service.gkehub_googleapis_com
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
