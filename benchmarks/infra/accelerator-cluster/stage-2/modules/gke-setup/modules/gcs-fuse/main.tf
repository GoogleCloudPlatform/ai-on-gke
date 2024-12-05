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

locals {
  bucket_name = (
    var.bucket_create
    ? module.gcs-fuse-bucket.0.name
    : data.google_storage_bucket.bucket.0.name
  )
}

data "google_service_account" "gsa" {
  account_id = var.google_service_account
  project    = var.project_id
}

data "google_storage_bucket" "bucket" {
  count = var.bucket_create ? 0 : 1
  name  = var.bucket_name
}

module "gcs-fuse-bucket" {
  source     = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/gcs?ref=v30.0.0&depth=1"
  count      = var.bucket_create ? 1 : 0
  project_id = var.project_id
  name       = var.bucket_name
  location   = var.bucket_location
}

resource "google_storage_bucket_iam_member" "bucket-iam" {
  bucket = local.bucket_name
  role   = "roles/storage.admin"
  member = "serviceAccount:${var.google_service_account}"
}
