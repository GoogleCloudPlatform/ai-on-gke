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

data "google_service_account" "gsa" {
  count      = var.google_service_account_create ? 0 : 1
  account_id = var.google_service_account
  project    = var.project_id
}

module "workload-service-account" {
  source      = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/iam-service-account?ref=v30.0.0&depth=1"
  count       = var.google_service_account_create ? 1 : 0
  project_id  = var.project_id
  name        = var.google_service_account
  description = "Service account for GKE workloads"
}

resource "google_service_account_iam_member" "ksa-bind-to-gsa" {
  service_account_id = local.wi_sa_name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.kubernetes_service_account}]"
}
