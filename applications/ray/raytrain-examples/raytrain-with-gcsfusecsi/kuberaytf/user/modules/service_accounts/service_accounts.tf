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

resource "google_service_account" "sa" {
  project      = "${var.project_id}"
  account_id   = "${var.service_account}"
  display_name = "GCP SA for Ray"
}

resource "google_service_account_iam_binding" "workload-identity-user" {
  service_account_id = google_service_account.sa.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.k8s_service_account}]",
  ]
  depends_on = [ google_service_account.sa ]
}

resource "google_storage_bucket_iam_binding"  "gcs-bucket-iam" {
  bucket = "${var.gcs_bucket}"
  role = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${google_service_account.sa.account_id}@${var.project_id}.iam.gserviceaccount.com",
  ]
}

resource "kubernetes_service_account" "ksa" {
  metadata {
    name = "${var.k8s_service_account}"
    namespace = "${var.namespace}"
  }
  automount_service_account_token = true
}

resource "kubernetes_annotations" "ray-sa-annotations" {
  api_version = "v1"
  kind        = "ServiceAccount"
  metadata {
    name = "${var.k8s_service_account}"
    namespace = "${var.namespace}"
  }
  annotations = {
    "iam.gke.io/gcp-service-account" = "${google_service_account.sa.account_id}@${var.project_id}.iam.gserviceaccount.com"
  }
  depends_on = [ 
    kubernetes_service_account.ksa,
    google_service_account.sa
    ]
}
