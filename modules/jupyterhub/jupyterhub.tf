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


locals {
  config_values_file = templatefile("${path.module}/jupyter_config/config.yaml", { password : random_password.generated_password.result })
}

output "filecontent" {
  value = local.config_values_file
}

resource "random_password" "generated_password" {
  length  = 12
  special = false
}

resource "helm_release" "jupyterhub" {
  name             = var.name
  repository       = "https://jupyterhub.github.io/helm-chart"
  chart            = "jupyterhub"
  version          = var.app_version
  namespace        = var.namespace
  create_namespace = var.create_namespace
  cleanup_on_fail  = "true"
  values = [
    local.config_values_file
  ]
}

