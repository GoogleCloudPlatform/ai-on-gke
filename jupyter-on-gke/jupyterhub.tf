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

provider "google-beta" {
  project = var.project_id
  region = var.location
}

resource "kubernetes_namespace" "namespace" {
  count = var.create_namespace ? 1 : 0
  metadata {
    labels = {
      namespace = var.namespace
    }

    name = var.namespace
  }
}

module "iap_auth" {
  count = var.add_auth ? 1 : 0
  source = "./iap_module"

  project_id = var.project_id
  location = var.location
  namespace  = var.namespace
  client_id = var.client_id
  client_secret = var.client_secret
  service_name = "k8s-be-32570--b8029e393bc6d64a"

  depends_on = [ kubernetes_namespace.namespace ]
}

resource "helm_release" "jupyterhub" {
  name       = "jupyterhub"
  repository = "https://jupyterhub.github.io/helm-chart"
  chart      = "jupyterhub"
  namespace  = var.namespace
  cleanup_on_fail = "true"

  values = [
    templatefile("${path.module}/jupyter_config/config-selfauth.yaml", {
      service_id = "${module.iap_auth[0].backend_service_id}"
      project_number = "${var.project_number}"
    })
  ]

  depends_on = [  
    module.iap_auth,
    kubernetes_namespace.namespace
  ]
}

