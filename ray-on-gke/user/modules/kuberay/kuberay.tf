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

resource "helm_release" "ray-cluster" {
  name       = "example-cluster"
  repository = "https://ray-project.github.io/kuberay-helm/"
  chart      = "ray-cluster"
  namespace  = var.namespace
  version    = "0.6.1"
  values     = var.enable_autopilot ? [file("${path.module}/kuberay-autopilot-values.yaml")] : (var.enable_tpu ? [file("${path.module}/kuberay-tpu-values.yaml")] : [file("${path.module}/kuberay-values.yaml")])
}

data "local_file" "tpu_worker_svc" {
  filename = "${path.module}/config/tpu-worker-svc.yaml"
}

resource "kubectl_manifest" "tpu_worker_svc" {
  override_namespace = var.namespace
  yaml_body          = data.local_file.tpu_worker_svc.content
}
