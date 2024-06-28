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

module "maxengine" {
  count                       = 1
  source                      = "../../../../../../modules/jetstream-maxtext-deployment"
  bucket_name                 = var.bucket_name
  metrics_port                = var.metrics_port
  maxengine_server_image      = var.maxengine_server_image
  jetstream_http_server_image = var.jetstream_http_server_image
  custom_metrics_enabled      = var.custom_metrics_enabled
  project_id                  = var.project_id
  metrics_adapter             = "custom-metrics-stackdriver-adapter"
  hpa_type                    = var.hpa_type
  hpa_max_replicas            = var.hpa_max_replicas
  hpa_min_replicas            = var.hpa_min_replicas
  hpa_averagevalue_target     = var.hpa_averagevalue_target
}