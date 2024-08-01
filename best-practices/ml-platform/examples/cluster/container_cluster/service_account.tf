# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  # Minimal roles for nodepool SA https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa
  cluster_sa_roles = [
    "roles/monitoring.viewer",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/autoscaling.metricsWriter",
    "roles/artifactregistry.reader",
    "roles/serviceusage.serviceUsageConsumer"
  ]
}

# Create dedicated service account for the cluster nodes
resource "google_service_account" "cluster" {
  project      = data.google_project.environment.project_id
  account_id   = "vm-${local.cluster_name}"
  display_name = "${local.cluster_name} Service Account"
  description  = "Terraform-managed service account for cluster ${local.cluster_name}"
}

# Bind minimum role list to the service account
resource "google_project_iam_member" "cluster_sa" {
  for_each = toset(local.cluster_sa_roles)
  project  = data.google_project.environment.project_id
  member   = google_service_account.cluster.member
  role     = each.value
}
