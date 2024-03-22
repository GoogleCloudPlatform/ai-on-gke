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
  version          = "1.1.0"
  namespace        = var.namespace
  cleanup_on_fail  = "true"
  create_namespace = var.create_namespace
}

module "kuberay-workload-identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  version             = "30.0.0" # Pinning to a previous version as current version (30.1.0) showed inconsitent behaviour with workload identity service accounts
  use_existing_gcp_sa = !var.create_service_account
  name                = var.google_service_account
  namespace           = var.namespace
  project_id          = var.project_id
  roles               = ["roles/cloudsql.client", "roles/monitoring.viewer"]

  automount_service_account_token = true

  depends_on = [helm_release.kuberay-operator]
}

resource "kubernetes_secret_v1" "service_account_token" {
  metadata {
    name      = "kuberay-sa-token"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = var.google_service_account
    }
  }
  type = "kubernetes.io/service-account-token"

  depends_on = [module.kuberay-workload-identity]
}
