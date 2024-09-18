# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

provider "google" {
  project = var.project_id
}

provider "google-beta" {
  project = var.project_id
}

data "google_client_config" "default" {}

data "google_project" "project" {
  project_id = var.project_id
}

data "google_container_cluster" "my_cluster" {
  name     = var.cluster_name
  location = var.location
  project  = var.project_id
}

locals {
  ca_certificate = base64decode(
    data.google_container_cluster.my_cluster.master_auth[0].cluster_ca_certificate,
  )
  host = "https://${data.google_container_cluster.my_cluster.endpoint}"
}
provider "kubernetes" {
  host                   = local.host
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = local.ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = local.host
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = local.ca_certificate
  }
}

module "namespace" {
  source           = "../../modules/kubernetes-namespace"
  create_namespace = true
  namespace        = var.namespace
}

module "inference-server" {
  source            = "../../modules/inference-service"
  namespace         = var.namespace
  additional_labels = var.additional_labels
  autopilot_cluster = var.autopilot_cluster
  depends_on        = [module.namespace]
}

resource "helm_release" "gmp-engine" {
  name      = "gmp-engine"
  chart     = "${path.module}/../../charts/gmp-engine/"
  namespace = var.namespace
  # Timeout is increased to guarantee sufficient scale-up time for Autopilot nodes.
  timeout = 1200
  values = [
    "${file("${path.module}/podmonitoring.yaml")}"
  ]
  depends_on = [module.namespace]
}
