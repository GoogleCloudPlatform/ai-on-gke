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

resource "helm_release" "kuberay-operator" {
  name             = var.name
  repository       = "https://ray-project.github.io/kuberay-helm/"
  chart            = "kuberay-operator"
  values           = var.autopilot_cluster ? [file("${path.module}/kuberay-operator-autopilot-values.yaml")] : [file("${path.module}/kuberay-operator-values.yaml")]
  version          = "1.0.0"
  namespace        = var.namespace
  cleanup_on_fail  = "true"
  create_namespace = var.create_namespace
}

# Grant access to batchv1/Jobs to kuberay-operator since the kuberay-operator role is missing some permissions.
# See https://github.com/ray-project/kuberay/issues/1706 for more details.
# TODO: remove this role binding once the kuberay-operator helm chart is upgraded to v1.1
resource "kubernetes_role_binding_v1" "kuberay_batch_jobs" {
  metadata {
    name      = "kuberay-operator-batch-jobs"
    namespace = var.namespace
  }

  subject {
    kind      = "ServiceAccount"
    name      = "kuberay-operator"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "kuberay-operator-batch-jobs"
  }

  depends_on = [helm_release.kuberay-operator]
}

resource "kubernetes_role_v1" "kuberay_batch_jobs" {
  metadata {
    name      = "kuberay-operator-batch-jobs"
    namespace = var.namespace
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["*"]
  }

  depends_on = [helm_release.kuberay-operator]
}
