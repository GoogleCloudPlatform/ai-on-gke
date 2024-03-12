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

resource "google_storage_bucket_iam_member" "gcs-bucket-iam" {
  bucket = var.gcs_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.google_service_account}@${var.project_id}.iam.gserviceaccount.com"
}

locals {
  security_context = chomp(yamlencode({ for k, v in var.security_context : k => v if v != null }))
}

resource "helm_release" "ray-cluster" {
  name             = var.name
  repository       = "https://ray-project.github.io/kuberay-helm/"
  chart            = "ray-cluster"
  namespace        = var.namespace
  create_namespace = true
  version          = "1.0.0"
  values = [
    var.autopilot_cluster ? templatefile("${path.module}/kuberay-autopilot-values.yaml", {
      gcs_bucket          = var.gcs_bucket
      k8s_service_account = var.google_service_account
      grafana_host        = var.grafana_host
      security_context    = local.security_context
      secret_name         = var.db_secret_name
      project_id          = var.project_id
      db_region           = var.db_region
      }) : var.enable_tpu ? templatefile("${path.module}/kuberay-tpu-values.yaml", {
      gcs_bucket          = var.gcs_bucket
      k8s_service_account = var.google_service_account
      grafana_host        = var.grafana_host
      security_context    = local.security_context
      secret_name         = var.db_secret_name
      project_id          = var.project_id
      db_region           = var.db_region
      }) : var.enable_gpu ? templatefile("${path.module}/kuberay-gpu-values.yaml", {
      gcs_bucket          = var.gcs_bucket
      k8s_service_account = var.google_service_account
      grafana_host        = var.grafana_host
      security_context    = local.security_context
      secret_name         = var.db_secret_name
      project_id          = var.project_id
      db_region           = var.db_region
      }) : templatefile("${path.module}/kuberay-values.yaml", {
      gcs_bucket          = var.gcs_bucket
      k8s_service_account = var.google_service_account
      grafana_host        = var.grafana_host
      security_context    = local.security_context
      secret_name         = var.db_secret_name
      project_id          = var.project_id
      db_region           = var.db_region
    })
  ]
}

data "kubernetes_service" "head-svc" {
  metadata {
    name      = "${helm_release.ray-cluster.name}-kuberay-head-svc"
    namespace = var.namespace
  }
  depends_on = [helm_release.ray-cluster]
}
