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
  cluster_name = var.cluster_name
  project_id = var.project_id
  metrics_adapter = "prometheus-adapter"
  custom_metrics_enabled = true

  bucket_name                 = var.bucket_name
  metrics_port                = var.metrics_port
  maxengine_server_image      = var.maxengine_server_image
  jetstream_http_server_image = var.jetstream_http_server_image

  hpa_configs = {
    min_replicas = 1
    max_replicas = 5
    rules = [{
      target_query = "accelerator_memory_used_percentage"
      average_value_target = 10
    }]
  }
}