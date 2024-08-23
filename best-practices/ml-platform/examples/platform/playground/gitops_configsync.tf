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
  namespace_default_kubernetes_service_account = "default"
  ray_head_kubernetes_service_account          = "ray-head"
  ray_worker_kubernetes_service_account        = "ray-worker"
}



# TEMPLATE MANIFESTS
###############################################################################
resource "null_resource" "template_manifests" {
  depends_on = [
    google_gke_hub_feature_membership.cluster_configmanagement,
    google_secret_manager_secret_version.git_config,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/template_manifests.sh"
    environment = {
      GIT_CONFIG_SECRET_NAME = local.git_config_secret_name
      GIT_REPOSITORY         = local.git_repository
      PROJECT_ID             = data.google_project.environment.project_id
    }
  }

  triggers = {
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/configsync", "**") : md5("${path.module}/templates/configsync/${f}")]))
    md5_script = filemd5("${path.module}/scripts/template_manifests.sh")
  }
}



# CLUSTER MANIFESTS
###############################################################################
resource "null_resource" "cluster_manifests" {
  depends_on = [
    google_gke_hub_feature_membership.cluster_configmanagement,
    google_secret_manager_secret_version.git_config,
    null_resource.template_manifests,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/cluster_manifests.sh"
    environment = {
      CLUSTER_ENV            = var.environment_name
      CLUSTER_NAME           = google_container_cluster.mlp.name
      GIT_CONFIG_SECRET_NAME = local.git_config_secret_name
      GIT_REPOSITORY         = local.git_repository
      PROJECT_ID             = data.google_project.environment.project_id
    }
  }

  triggers = {
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/configsync/templates/_cluster_template", "**") : md5("${path.module}/templates/configsync/templates/_cluster_template${f}")]))
    md5_script = filemd5("${path.module}/scripts/cluster_manifests.sh")
  }
}



# GIT CREDENTIALS SECRET CONFIGSYNC
###############################################################################
resource "null_resource" "git_cred_secret_cms" {
  depends_on = [
    google_gke_hub_feature_membership.cluster_configmanagement,
    google_secret_manager_secret_version.git_config,
    null_resource.connect_gateway_kubeconfig,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/git_cred_secret.sh"
    environment = {
      GIT_CONFIG_SECRET_NAME = local.git_config_secret_name
      GIT_REPOSITORY         = local.git_repository
      K8S_NAMESPACE          = "config-management-system"
      KUBECONFIG             = "${local.kubeconfig_dir}/${data.google_project.environment.project_id}_${google_gke_hub_membership.cluster.membership_id}"
      PROJECT_ID             = data.google_project.environment.project_id
    }
  }

  triggers = {
    md5_credentials = md5(join("", [var.git_user_name, var.git_token]))
    md5_script      = filemd5("${path.module}/scripts/git_cred_secret.sh")
  }
}



# KUEUE
###############################################################################
resource "null_resource" "kueue" {
  depends_on = [
    google_gke_hub_feature_membership.cluster_configmanagement,
    google_secret_manager_secret_version.git_config,
    null_resource.cluster_manifests,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/kueue_manifests.sh"
    environment = {
      GIT_CONFIG_SECRET_NAME = local.git_config_secret_name
      GIT_REPOSITORY         = local.git_repository
      PROJECT_ID             = data.google_project.environment.project_id
    }
  }

  triggers = {
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/configsync/templates/_cluster_template", "**") : md5("${path.module}/templates/configsync/templates/_cluster_template/${f}")]))
    md5_script = filemd5("${path.module}/scripts/kueue_manifests.sh")
  }
}



# NVIDIA DCGM
###############################################################################
# resource "null_resource" "nvidia_dcgm" {
#   depends_on = [
#     google_gke_hub_feature_membership.cluster_configmanagement,
#     google_secret_manager_secret_version.git_config,
#     null_resource.kueue,
#   ]

#   provisioner "local-exec" {
#     command = "${path.module}/scripts/nvidia_dcgm_manifests.sh"
#     environment = {
#       GIT_CONFIG_SECRET_NAME = local.git_config_secret_name
#       GIT_REPOSITORY = local.git_repository
#       PROJECT_ID = data.google_project.environment.project_id
#     }
#   }

#   triggers = {
#     md5_files  = md5(join("", [for f in fileset("${path.module}/templates/configsync/templates/_cluster_template/gmp-public/nvidia-dcgm", "**") : md5("${path.module}/templates/configsync/templates/_cluster_template/gmp-public/nvidia-dcgm/${f}")]))
#     md5_script = filemd5("${path.module}/scripts/nvidia_dcgm_manifests.sh")
#   }
# }



# KUBERAY MANIFESTS
###############################################################################
resource "null_resource" "kuberay_manifests" {
  depends_on = [
    google_gke_hub_feature_membership.cluster_configmanagement,
    google_secret_manager_secret_version.git_config,
    null_resource.kueue,
    #null_resource.nvidia_dcgm,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/kuberay_manifests.sh"
    environment = {
      GIT_CONFIG_SECRET_NAME = local.git_config_secret_name
      GIT_REPOSITORY         = local.git_repository
      K8S_NAMESPACE          = var.namespace
      PROJECT_ID             = data.google_project.environment.project_id
    }
  }

  triggers = {
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/configsync/templates/_cluster_template/kuberay", "**") : md5("${path.module}/templates/configsync/templates/_cluster_template/kuberay/${f}")]))
    md5_script = filemd5("${path.module}/scripts/kuberay_manifests.sh")
  }
}



# NAMESPACE
###############################################################################
resource "null_resource" "namespace_manifests" {
  depends_on = [
    google_gke_hub_feature_membership.cluster_configmanagement,
    google_secret_manager_secret_version.git_config,
    null_resource.connect_gateway_kubeconfig,
    null_resource.kuberay_manifests,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/namespace_manifests.sh"
    environment = {
      CLUSTER_ENV            = var.environment_name
      CLUSTER_NAME           = google_container_cluster.mlp.name
      GIT_CONFIG_SECRET_NAME = local.git_config_secret_name
      GIT_REPOSITORY         = local.git_repository
      K8S_NAMESPACE          = self.triggers.namespace
      PROJECT_ID             = data.google_project.environment.project_id
    }
  }

  provisioner "local-exec" {
    command = "scripts/namespace_cleanup.sh"
    environment = {
      ENVIRONMENT_NAME       = self.triggers.environment_name
      GIT_CONFIG_SECRET_NAME = self.triggers.git_config_secret_name
      GIT_REPOSITORY         = self.triggers.git_repository
      KUBECONFIG             = self.triggers.kubeconfig
      K8S_NAMESPACE          = self.triggers.namespace
      PROJECT_ID             = self.triggers.project_id
      REPO_SYNC_NAME         = self.triggers.repo_sync_name
      REPO_SYNC_NAMESPACE    = self.triggers.repo_sync_namespace
      ROOT_SYNC_NAME         = self.triggers.root_sync_name
    }
    when        = destroy
    working_dir = path.module
  }

  triggers = {
    environment_name       = var.environment_name
    git_config_secret_name = local.git_config_secret_name
    git_repository         = local.git_repository
    kubeconfig             = "${local.kubeconfig_dir}/${data.google_project.environment.project_id}_${google_gke_hub_membership.cluster.membership_id}"
    project_id             = data.google_project.environment.project_id
    md5_files              = md5(join("", [for f in fileset("${path.module}/templates/configsync/templates/_cluster_template/team", "**") : md5("${path.module}/templates/configsync/templates/_cluster_template/team/${f}")]))
    md5_script             = filemd5("${path.module}/scripts/namespace_manifests.sh")
    namespace              = var.namespace
    repo_sync_name         = "${var.environment_name}-${var.namespace}"
    repo_sync_namespace    = var.namespace
    root_sync_name         = "root-sync"
  }
}



# GIT CREDENTIALS SECRET NAMESPACE
###############################################################################
resource "null_resource" "git_cred_secret_ns" {
  depends_on = [
    null_resource.connect_gateway_kubeconfig,
    google_secret_manager_secret_version.git_config,
    null_resource.namespace_manifests,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/git_cred_secret.sh"
    environment = {
      GIT_CONFIG_SECRET_NAME = local.git_config_secret_name
      K8S_NAMESPACE          = var.namespace
      KUBECONFIG             = "${local.kubeconfig_dir}/${data.google_project.environment.project_id}_${google_gke_hub_membership.cluster.membership_id}"
      PROJECT_ID             = data.google_project.environment.project_id
    }
  }

  triggers = {
    md5_credentials = md5(join("", [var.git_user_name, var.git_token]))
    md5_script      = filemd5("${path.module}/scripts/git_cred_secret.sh")
  }
}



# KUBERAY WATCH NAMESPACE MANIFESTS
###############################################################################
resource "null_resource" "kuberay_watch_namespace_manifests" {
  depends_on = [
    google_gke_hub_feature_membership.cluster_configmanagement,
    google_secret_manager_secret_version.git_config,
    null_resource.namespace_manifests,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/kuberay_watch_namespace_manifests.sh"
    environment = {
      GIT_CONFIG_SECRET_NAME = local.git_config_secret_name
      GIT_REPOSITORY         = local.git_repository
      K8S_NAMESPACE          = var.namespace
      PROJECT_ID             = data.google_project.environment.project_id
    }
  }

  triggers = {
    md5_script = filemd5("${path.module}/scripts/kuberay_watch_namespace_manifests.sh")
  }
}



# RAY CLUSTER IN NAMESPACE
###############################################################################
resource "null_resource" "ray_cluster_namespace_manifests" {
  depends_on = [
    google_gke_hub_feature_membership.cluster_configmanagement,
    google_secret_manager_secret_version.git_config,
    null_resource.kuberay_watch_namespace_manifests,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/ray_cluster_namespace_manifests.sh"
    environment = {
      GIT_CONFIG_SECRET_NAME     = local.git_config_secret_name
      GIT_REPOSITORY             = local.git_repository
      K8S_NAMESPACE              = var.namespace
      K8S_SERVICE_ACCOUNT_HEAD   = local.ray_head_kubernetes_service_account
      K8S_SERVICE_ACCOUNT_WORKER = local.ray_worker_kubernetes_service_account
      PROJECT_ID                 = data.google_project.environment.project_id
    }
  }

  triggers = {
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/configsync/templates/_namespace_template/app", "**") : md5("${path.module}/templates/configsync/templates/_namespace_template/app/${f}")]))
    md5_script = filemd5("${path.module}/scripts/ray_cluster_namespace_manifests.sh")
  }
}



# GATEWAY
###############################################################################
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
    google_compute_managed_ssl_certificate.external_gateway,
    google_endpoints_service.ray_dashboard_https,
    google_gke_hub_feature_membership.cluster_configmanagement,
    google_secret_manager_secret_version.git_config,
    kubernetes_secret_v1.ray_head_client,
    null_resource.ray_cluster_namespace_manifests,
  ]

  provisioner "local-exec" {
    command = "scripts/gateway_manifests.sh"
    environment = {
      ENVIRONMENT_NAME       = self.triggers.environment_name
      GIT_CONFIG_SECRET_NAME = self.triggers.git_config_secret_name
      GIT_REPOSITORY         = self.triggers.git_repository
      KUBECONFIG             = self.triggers.kubeconfig
      K8S_NAMESPACE          = self.triggers.namespace
      PROJECT_ID             = self.triggers.project_id
      REPO_SYNC_NAME         = self.triggers.repo_sync_name
      REPO_SYNC_NAMESPACE    = self.triggers.repo_sync_namespace
    }
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }

  provisioner "local-exec" {
    command = "scripts/gateway_cleanup.sh"
    environment = {
      GIT_CONFIG_SECRET_NAME = self.triggers.git_config_secret_name
      GIT_REPOSITORY         = self.triggers.git_repository
      K8S_NAMESPACE          = self.triggers.namespace
      KUBECONFIG             = self.triggers.kubeconfig
      PROJECT_ID             = self.triggers.project_id
      REPO_SYNC_NAME         = self.triggers.repo_sync_name
      REPO_SYNC_NAMESPACE    = self.triggers.repo_sync_namespace
    }
    interpreter = ["bash", "-c"]
    when        = destroy
    working_dir = path.module
  }

  triggers = {
    environment_name       = var.environment_name
    gateway_name           = local.gateway_name
    git_config_secret_name = local.git_config_secret_name
    git_repository         = local.git_repository
    github_email           = var.git_user_email
    github_token           = var.git_token
    github_user            = var.git_user_name
    kubeconfig             = "${local.kubeconfig_dir}/${data.google_project.environment.project_id}_${google_gke_hub_membership.cluster.membership_id}"
    md5_script             = filemd5("${path.module}/scripts/gateway_manifests.sh")
    md5_files = md5(join("", [
      local_file.gateway_external_https_yaml.content_md5,
      local_file.policy_iap_ray_head_yaml.content_md5,
      local_file.route_ray_dashboard_https_yaml.content_md5,
      local_file.gateway_kustomization_yaml.content_md5
    ]))
    namespace           = data.kubernetes_namespace_v1.team.metadata[0].name
    project_id          = data.google_project.environment.project_id
    repo_sync_name      = "${var.environment_name}-${data.kubernetes_namespace_v1.team.metadata[0].name}"
    repo_sync_namespace = data.kubernetes_namespace_v1.team.metadata[0].name

  }
}



# WAIT FOR CONFIGSYNC
###############################################################################
resource "null_resource" "wait_for_configsync" {
  depends_on = [
    google_gke_hub_feature_membership.cluster_configmanagement,
    google_secret_manager_secret_version.git_config,
    null_resource.gateway_manifests,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait_for_configsync.sh"
    environment = {
      GIT_CONFIG_SECRET_NAME = local.git_config_secret_name
      GIT_REPOSITORY         = local.git_repository
      KUBECONFIG             = "${local.kubeconfig_dir}/${data.google_project.environment.project_id}_${google_gke_hub_membership.cluster.membership_id}"
      PROJECT_ID             = data.google_project.environment.project_id
      REPO_SYNC_NAME         = "${var.environment_name}-${data.kubernetes_namespace_v1.team.metadata[0].name}"
      REPO_SYNC_NAMESPACE    = data.kubernetes_namespace_v1.team.metadata[0].name
      ROOT_SYNC_NAME         = "root-sync"
    }
  }

  triggers = {
    md5_script = filemd5("${path.module}/scripts/wait_for_configsync.sh")
  }
}
