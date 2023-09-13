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

data "local_file" "fluentd_config_yaml" {
  filename = "${path.module}/config/fluentd_config.yaml"
}

data "local_file" "redis_config_map_yaml" {
  filename = "${path.module}/redis-config/config-map.yaml"
}

data "local_file" "redis_service_yaml" {
  filename = "${path.module}/redis-config/service.yaml"
}

data "local_file" "redis_deployment_yaml" {
  filename = "${path.module}/redis-config/deployment.yaml"
}

data "local_file" "redis_secret_yaml" {
  filename = "${path.module}/redis-config/secret.yaml"
}

resource "kubernetes_namespace" "ml" {
  metadata {
    name = var.namespace
  }
}

resource "kubectl_manifest" "fluentd_config" {
  override_namespace = var.namespace
  yaml_body          = data.local_file.fluentd_config_yaml.content
}

resource "kubectl_manifest" "redis_config_map" {
  count = var.enable_fault_tolerance ? 1 : 0 
  override_namespace = var.namespace
  yaml_body          = data.local_file.redis_config_map_yaml.content
}

resource "kubectl_manifest" "redis_secret" {
  count = var.enable_fault_tolerance ? 1 : 0
  override_namespace = var.namespace
  yaml_body          = data.local_file.redis_secret_yaml.content
}

resource "kubectl_manifest" "redis_service" {
  count = var.enable_fault_tolerance ? 1 : 0
  override_namespace = var.namespace
  yaml_body          = data.local_file.redis_service_yaml.content
}

resource "kubectl_manifest" "redis_deployment" {
  count = var.enable_fault_tolerance ? 1 : 0
  override_namespace = var.namespace
  yaml_body          = data.local_file.redis_deployment_yaml.content
}

