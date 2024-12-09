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

variable "billing_account_id" {
  description = "Google Cloud Billing Account ID"
  type        = string
  nullable    = false
}

variable "folder_id" {
  description = "Google Cloud Folder ID"
  type        = string
  nullable    = false
}

variable "impersonate_service_account" {
  description = "Service account to be used while using Google Cloud APIs"
  type        = string
  nullable    = true
  default     = null
}

variable "region" {
  description = "Google Cloud Region where the GKE cluster is located"
  type        = string
  nullable    = false
}

variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
  nullable    = false
}
