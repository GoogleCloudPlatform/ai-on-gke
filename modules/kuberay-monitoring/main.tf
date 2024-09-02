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

# create frontend service for google managed prometheus engine
resource "helm_release" "gmp-ray-monitoring" {
  name             = "gmp-ray-monitoring"
  chart            = "${path.module}/../../charts/gmp-engine/"
  namespace        = var.namespace
  create_namespace = var.create_namespace
  # Timeout is increased to guarantee sufficient scale-up time for Autopilot nodes.
  timeout = 1200
  set {
    name  = "gmp-frontend.projectID"
    value = var.project_id
  }
  set {
    name  = "gmp-frontend.serviceAccount"
    value = var.k8s_service_account
  }
}

# grafana
resource "helm_release" "grafana" {
  count            = var.enable_grafana_on_ray_dashboard ? 1 : 0
  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  namespace        = var.namespace
  create_namespace = var.create_namespace
  version          = "7.0.0"
  wait             = "true"
  values = [templatefile("${path.module}/grafana/values.yaml", {
    k8s_service_account : var.k8s_service_account
  })]
}

data "kubernetes_service" "example" {
  count = var.enable_grafana_on_ray_dashboard ? 1 : 0
  metadata {
    name      = "grafana"
    namespace = var.namespace
  }
  depends_on = [helm_release.grafana]
}
