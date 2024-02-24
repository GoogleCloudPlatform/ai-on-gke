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

resource "google_storage_bucket_iam_member"  "gcs-bucket-iam" {
  bucket = "${var.gcs_bucket}"
  role = "roles/storage.objectAdmin"
  member  = "serviceAccount:${var.google_service_account}@${var.project_id}.iam.gserviceaccount.com"
}

resource "helm_release" "ray-cluster" {
  name             = "example-cluster"
  repository       = "https://ray-project.github.io/kuberay-helm/"
  chart            = "ray-cluster"
  namespace        = var.namespace
  create_namespace = var.create_namespace
  version          = "0.6.1"
  values = var.enable_autopilot ? [templatefile("${path.module}/kuberay-autopilot-values.yaml", {
    gcs_bucket          = var.gcs_bucket
    k8s_service_account = var.google_service_account
    grafana_host        = var.grafana_host
    })] : (var.enable_tpu ? [templatefile("${path.module}/kuberay-tpu-values.yaml", {
      gcs_bucket          = var.gcs_bucket
      k8s_service_account = var.google_service_account
      grafana_host        = var.grafana_host
      })] : [templatefile("${path.module}/kuberay-values.yaml", {
      gcs_bucket          = var.gcs_bucket
      k8s_service_account = var.google_service_account
      grafana_host        = var.grafana_host
  })])
}

resource "kubernetes_service" "tpu-worker-svc" {
  count = var.enable_tpu ? 1 : 0
  metadata {
    name = "${helm_release.ray-cluster.name}-kuberay-tpu-worker-svc"
  }
  spec {
    selector = {
      "cloud.google.com/gke-ray-node-type" = "worker"
    }
    cluster_ip = "None"
  }
}
