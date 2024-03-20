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

data "kubernetes_all_namespaces" "allns" {}

# Terraform Kubernetes namespaces are not declarative or idempotent.
# Two attempts to create the same namespace will error out. Calculate
# whether a namespace already exists then skip creation if it does.
locals {
  namespace_exists = contains(data.kubernetes_all_namespaces.allns.namespaces, var.namespace) ? true : false
}

resource "kubernetes_namespace" "namespace" {
  count = local.namespace_exists ? 0 : 1
  metadata {
    name = var.namespace
    annotations = var.annotations
    labels = var.labels
  }
}
