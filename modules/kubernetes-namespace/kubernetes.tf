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

resource "kubernetes_namespace" "ml" {
  metadata {
    name = var.namespace
  }
}

resource "kubectl_manifest" "fluentd_config" {
  override_namespace = var.namespace
  yaml_body          = data.local_file.fluentd_config_yaml.content
}
