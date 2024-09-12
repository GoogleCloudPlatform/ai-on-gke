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
  host                   = "https://${data.google_container_cluster.nim_llm.endpoint}"
  cluster_ca_certificate = base64decode(data.google_container_cluster.nim_llm.master_auth.0.cluster_ca_certificate)
  token                  = data.google_client_config.current.access_token
}

provider "google" {
  project = var.google_project
}

provider "kubernetes" {
  host                   = local.host
  cluster_ca_certificate = local.cluster_ca_certificate
  token                  = local.token
}

provider "helm" {
  kubernetes {
    host                   = local.host
    cluster_ca_certificate = local.cluster_ca_certificate
    token                  = local.token
  }
}

