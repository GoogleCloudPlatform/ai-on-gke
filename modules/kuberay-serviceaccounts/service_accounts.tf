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

# Create service account for Prometheus
resource "google_service_account" "sa_prom" {
  project      = var.project_id
  account_id   = var.gcp_service_account_prom
  display_name = "Managed prometheus service account"
}

resource "google_service_account_iam_binding" "workload-identity-user-prom" {
  service_account_id = google_service_account.sa_prom.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.k8s_service_account_prom}]",
  ]
}

resource "google_project_iam_binding" "monitoring-viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"

  members = [
    "serviceAccount:${google_service_account.sa_prom.account_id}@${var.project_id}.iam.gserviceaccount.com",
  ]
}
resource "google_project_iam_binding" "monitoring-viewer-sa" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"

  members = [
    "serviceAccount:${google_service_account.sa_prom.account_id}@${var.project_id}.iam.gserviceaccount.com",
  ]
}

resource "kubernetes_service_account" "ksa-prom" {
  count = var.create_k8s_service_account_prom ? 1 : 0
  metadata {
    name      = var.k8s_service_account_prom
    namespace = var.namespace
  }
  lifecycle { ignore_changes = [metadata[0].annotations] }

}

resource "kubernetes_annotations" "default" {
  api_version = "v1"
  kind        = "ServiceAccount"
  metadata {
    name = var.k8s_service_account_prom
    namespace = var.namespace
  }
  annotations = {
    "iam.gke.io/gcp-service-account" = "${google_service_account.sa_prom.account_id}@${var.project_id}.iam.gserviceaccount.com"
  }
}

# Create service account for GCS
resource "google_service_account" "sa_gcs" {
  project      = var.project_id
  account_id   = var.gcp_service_account_gcs
  display_name = "GCP SA for Ray"
}

resource "google_service_account_iam_binding" "workload-identity-user-gcs" {
  service_account_id = google_service_account.sa_gcs.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.k8s_service_account_gcs}]",
  ]
  depends_on = [google_service_account.sa_gcs]
}

resource "google_storage_bucket_iam_binding" "gcs-bucket-iam" {
  bucket = var.gcs_bucket
  role   = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${google_service_account.sa_gcs.account_id}@${var.project_id}.iam.gserviceaccount.com",
  ]
}

resource "kubernetes_service_account" "ksa" {
  count = var.create_k8s_service_account_gcs ? 1 : 0
  metadata {
    name      = var.k8s_service_account_gcs
    namespace = var.namespace
  }
  automount_service_account_token = true
  lifecycle { ignore_changes = [metadata[0].annotations] }
}

resource "kubernetes_annotations" "ray-sa-annotations" {
  api_version = "v1"
  kind        = "ServiceAccount"
  metadata {
    name      = var.k8s_service_account_gcs
    namespace = var.namespace
  }
  annotations = {
    "iam.gke.io/gcp-service-account" = "${google_service_account.sa_gcs.account_id}@${var.project_id}.iam.gserviceaccount.com"
  }
  depends_on = [
    kubernetes_service_account.ksa,
    google_service_account.sa_gcs
  ]
}