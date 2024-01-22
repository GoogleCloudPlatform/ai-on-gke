# Copyright 2023 Google LLC
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

data "google_client_config" "provider" {}

provider "kubernetes" {
  config_path = pathexpand("~/.kube/config")
}

provider "kubectl" {
  config_path = pathexpand("~/.kube/config")
}

provider "helm" {
  kubernetes {
    config_path = pathexpand("~/.kube/config")
  }
}

# module "kubernetes" {
#   source = "./modules/kubernetes"

#   namespace = var.namespace
# }

module "service_accounts" {
  source = "./modules/service_accounts"

  # depends_on = [module.kubernetes]
  project_id = var.project_id
  namespace  = var.namespace
  service_account = var.service_account
  gcs_bucket = var.gcs_bucket
}

module "kuberay" {
  source = "./modules/kuberay"

  depends_on = [
    # module.kubernetes,
    module.service_accounts
  ]
  namespace  = var.namespace
}