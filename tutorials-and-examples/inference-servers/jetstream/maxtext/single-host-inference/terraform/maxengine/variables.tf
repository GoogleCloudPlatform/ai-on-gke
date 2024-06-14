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

variable "bucket_name" {
  description = "Name of Google Cloud Storage bucket hosting unscanned checkpoints"
  type        = string
  nullable    = false
}

variable "metrics_port" {
  description = "Port to emit metrics from"
  type        = number
  default     = 9100
  nullable    = true
}

variable "maxengine_server_image" {
  description = "maxengine-server container image"
  type        = string
  default     = "us-docker.pkg.dev/cloud-tpu-images/inference/maxengine-server:v0.2.2"
  nullable    = false
}

variable "jetstream_http_server_image" {
  description = "jetstream-http container image"
  type        = string
  default     = "us-docker.pkg.dev/cloud-tpu-images/inference/jetstream-http:v0.2.2"
  nullable    = false
}

