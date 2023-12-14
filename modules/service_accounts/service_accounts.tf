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
  display_name = "Terraform managed service account for ai-on-gke"
}

resource "google_service_account_iam_binding" "workload-identity-user" {
  service_account_id = google_service_account.sa.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/default]",
  ]
}

resource "google_project_iam_binding" "monitoring-viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/default]",
  ]
}

resource "kubernetes_annotations" "default" {
  api_version = "v1"
  kind        = "ServiceAccount"
  metadata {
    name = "default"
    namespace = "${var.namespace}"
  }
  annotations = {
    "iam.gke.io/gcp-service-account" = "${google_service_account.sa.account_id}@${var.project_id}.iam.gserviceaccount.com"
  }
}
