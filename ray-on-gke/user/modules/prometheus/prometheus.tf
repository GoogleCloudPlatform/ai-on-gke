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

data "local_file" "pod_monitor_yaml" {
  filename = "${path.module}/config/pod_monitor.yaml"
}

data "local_file" "frontend_deployment" {
  filename = "${path.module}/config/frontend-deployment.yaml"
}

data "local_file" "grafana_deployment" {
  filename = "${path.module}/config/grafana-deployment.yaml"
}

data "local_file" "frontend_service" {
  filename = "${path.module}/config/frontend-service.yaml"
}

data "local_file" "grafana_service" {
  filename = "${path.module}/config/grafana-service.yaml"
}

resource "kubectl_manifest" "pod_monitor" {
  override_namespace = var.namespace
  yaml_body          = data.local_file.pod_monitor_yaml.content
}

resource "kubectl_manifest" "prometheus_frontend" {
  override_namespace = var.namespace
  yaml_body          = replace(data.local_file.frontend_deployment.content, "$PROJECT_ID", var.project_id)
}

resource "kubectl_manifest" "prometheus_grafana" {
  override_namespace = var.namespace
  yaml_body          = data.local_file.grafana_deployment.content
}

resource "kubectl_manifest" "prometheus_frontend_service" {
  override_namespace = var.namespace
  yaml_body          = data.local_file.frontend_service.content
}

resource "kubectl_manifest" "prometheus_grafana_service" {
  override_namespace = var.namespace
  yaml_body          = data.local_file.grafana_service.content
}
