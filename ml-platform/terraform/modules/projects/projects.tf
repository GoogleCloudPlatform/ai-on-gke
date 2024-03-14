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

resource "random_id" "random_project_id_suffix" {
  byte_length = 2
}

resource "google_project" "project_under_folder" {
  for_each = var.folder_id != null ? var.env : toset([])

  billing_account = var.billing_account
  folder_id       = var.folder_id
  name            = format("%s-%s", var.project_name, each.value)
  project_id      = format("%s-%s-%s", var.project_name, random_id.random_project_id_suffix.hex, each.value)
}

resource "google_project" "project_under_org" {
  for_each = var.folder_id == null ? var.env : toset([])

  billing_account = var.billing_account
  name            = format("%s-%s", var.project_name, each.value)
  org_id          = var.org_id
  project_id      = format("%s-%s-%s", var.project_name, random_id.random_project_id_suffix.hex, each.value)
}

resource "google_project_service" "project_services" {
  for_each = var.folder_id == null ? google_project.project_under_org : google_project.project_under_folder

  depends_on = [google_project.project_under_folder, google_project.project_under_org]

  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = each.value.id
  service                    = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "project_services-1" {
  for_each = var.folder_id == null ? google_project.project_under_org : google_project.project_under_folder

  depends_on = [google_project.project_under_folder, google_project.project_under_org]

  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = each.value.id
  service                    = "iam.googleapis.com"
}

resource "google_project_service" "project_services-2" {
  for_each = var.folder_id == null ? google_project.project_under_org : google_project.project_under_folder

  depends_on = [google_project.project_under_folder, google_project.project_under_org]

  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = each.value.id
  service                    = "container.googleapis.com"
}

resource "google_project_service" "project_services-3" {
  for_each = var.folder_id == null ? google_project.project_under_org : google_project.project_under_folder

  depends_on = [google_project.project_under_folder, google_project.project_under_org]

  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = each.value.id
  service                    = "compute.googleapis.com"
}

resource "google_project_service" "project_services-4" {
  for_each = var.folder_id == null ? google_project.project_under_org : google_project.project_under_folder

  depends_on = [google_project.project_under_folder, google_project.project_under_org]

  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = each.value.id
  service                    = "anthos.googleapis.com"
}

resource "google_project_service" "project_services-5" {
  for_each = var.folder_id == null ? google_project.project_under_org : google_project.project_under_folder

  depends_on = [google_project.project_under_folder, google_project.project_under_org]

  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = each.value.id
  service                    = "anthosconfigmanagement.googleapis.com"
}

resource "google_project_service" "project_services-6" {
  for_each = var.folder_id == null ? google_project.project_under_org : google_project.project_under_folder

  depends_on = [google_project.project_under_folder, google_project.project_under_org]

  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = each.value.id
  service                    = "gkehub.googleapis.com"
}
