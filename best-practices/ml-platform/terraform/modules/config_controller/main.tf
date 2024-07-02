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
  cluster_name         = "krmapihost-${var.name}"
  kubeconfig_file_name = "${var.project_id}_${local.cluster_name}"
  kubeconfig_file_path = "${var.kubeconfig_directory}/${local.kubeconfig_file_name}"
}

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_project_service" "anthos_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.project.project_id
  service                    = "anthos.googleapis.com"
}

resource "google_project_service" "cloudresourcemanager_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.project.project_id
  service                    = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "container_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.project.project_id
  service                    = "container.googleapis.com"
}

resource "google_project_service" "krmapihosting_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.project.project_id
  service                    = "krmapihosting.googleapis.com"
}

resource "google_project_service" "serviceusage_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.project.project_id
  service                    = "serviceusage.googleapis.com"
}

resource "null_resource" "config_controller" {
  provisioner "local-exec" {
    command = "scripts/gcloud_create.sh"
    environment = {
      FULL_MANAGEMENT = self.triggers.FULL_MANAGEMENT
      LOCATION        = self.triggers.LOCATION
      NAME            = self.triggers.NAME
      NETWORK         = self.triggers.NETWORK
      PROJECT_ID      = self.triggers.PROJECT_ID
      SUBNET          = self.triggers.SUBNET
    }
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }

  provisioner "local-exec" {
    command = "scripts/gcloud_delete.sh"
    environment = {
      LOCATION   = self.triggers.LOCATION
      NAME       = self.triggers.NAME
      PROJECT_ID = self.triggers.PROJECT_ID
    }
    interpreter = ["bash", "-c"]
    when        = destroy
    working_dir = path.module
  }

  triggers = {
    FULL_MANAGEMENT = var.full_management
    LOCATION        = var.location
    NAME            = var.name
    NETWORK         = var.network
    PROJECT_ID      = var.project_id
    SUBNET          = var.subnet
  }
}

data "google_container_cluster" "config_controller" {
  depends_on = [
    null_resource.config_controller
  ]

  location = var.location
  name     = local.cluster_name
  project  = data.google_project.project.project_id
}

resource "null_resource" "kubeconfig" {
  provisioner "local-exec" {
    command     = <<EOT
KUBECONFIG="${self.triggers.KUBECONFIG_FILE_NAME}" \
gcloud anthos config controller get-credentials ${self.triggers.NAME} \
--location ${self.triggers.LOCATION} \
--project ${self.triggers.PROJECT_ID}
    EOT
    interpreter = ["bash", "-c"]
    working_dir = self.triggers.KUBECONFIG_DIRECTORY
  }

  provisioner "local-exec" {
    command     = "rm -f ${self.triggers.KUBECONFIG_FILE_NAME}"
    when        = destroy
    interpreter = ["bash", "-c"]
    working_dir = self.triggers.KUBECONFIG_DIRECTORY
  }

  triggers = {
    NAME                 = var.name
    KUBECONFIG_DIRECTORY = var.kubeconfig_directory
    KUBECONFIG_FILE_NAME = local.kubeconfig_file_name
    LOCATION             = var.location
    PROJECT_ID           = data.google_project.project.project_id
  }
}
