/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

module "gcs-result-bucket" {
  source     = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/gcs?ref=v30.0.0&depth=1"
  project_id = var.project_id
  name       = var.output_bucket_name
  location   = var.output_bucket_location
}

resource "google_storage_bucket_iam_member" "bucket-iam" {
  bucket = module.gcs-result-bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.google_service_account}"
}

resource "google_project_iam_member" "metrics-iam" {
  role    = "roles/monitoring.viewer"
  project = var.project_id
  member  = "serviceAccount:${var.google_service_account}"
}

resource "google_compute_address" "benchmark-tool-runner-endpoint" {
  project = var.project_id
  region  = var.cluster_region
  name    = "benchmark-tool-runner-endpoint"
}
