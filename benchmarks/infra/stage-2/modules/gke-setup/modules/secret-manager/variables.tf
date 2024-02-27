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

variable "project_id" {
  description = "Project id of existing or created project."
  nullable    = false
  type        = string
}

variable "google_service_account" {
  description = "Name for the Google Service Account to be used for benchmark"
  type        = string
  nullable    = false
  default     = "benchmark-sa"
}

variable "secret_name" {
  description = "Secret name"
  type        = string
  nullable    = true
}

variable "secret_location" {
  description = "Location of secret"
  type        = string
  nullable    = true
}
