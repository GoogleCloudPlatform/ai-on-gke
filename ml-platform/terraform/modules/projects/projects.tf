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
  create_project           = var.project_id == "" ? 1 : 0
  project_id               = var.project_id == "" ? google_project.environment[0].project_id : var.project_id
  project_id_prefix        = "${var.project_name}-${var.env}"
  project_id_suffix_length = 29 - length(local.project_id_prefix)
}

resource "random_string" "project_id_suffix" {
  length  = local.project_id_suffix_length
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "google_project" "environment" {
  count = local.create_project

  billing_account = var.billing_account
  folder_id       = var.folder_id == "" ? null : var.folder_id
  name            = local.project_id_prefix
  org_id          = var.org_id == "" ? null : var.org_id
  project_id      = "${local.project_id_prefix}-${random_string.project_id_suffix.result}"
}

data "google_project" "environment" {
  depends_on = [google_project.environment]

  project_id = local.project_id
}
