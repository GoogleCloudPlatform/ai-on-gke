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
  hpa_cpu_template           = "${path.module}/hpa-templates/hpa.cpu.yaml.tftpl"
  hpa_custom_metric_template = "${path.module}/hpa-templates/hpa.jetstream.custom_metric.yaml.tftpl"
  jetstream_podmonitoring    = "${path.module}/monitoring-templates/jetstream-podmonitoring.yaml.tftpl"
}

module "custom_metrics_stackdriver_adapter" {
  count  = var.custom_metrics_enabled ? 1 : 0
  source = "./custom-metrics-stackdriver-adapter"
  workload_identity = {
    enabled    = true
    project_id = var.project_id
  }
}

module "maxengine" {
  count                       = 1
  source                      = "./maxengine"
  bucket_name                 = var.bucket_name
  metrics_port                = var.metrics_port
  maxengine_server_image      = var.maxengine_server_image
  jetstream_http_server_image = var.jetstream_http_server_image
}

resource "kubernetes_manifest" "tgi-pod-monitoring" {
  count = var.custom_metrics_enabled && var.metrics_port != null ? 1 : 0
  manifest = yamldecode(templatefile(local.jetstream_podmonitoring, {
    namespace    = var.namespace
    metrics_port = try(var.metrics_port, -1)
  }))
}

resource "kubernetes_manifest" "hpa_custom_metric" {
  count = var.custom_metrics_enabled && var.hpa_type != null && var.hpa_averagevalue_target != null ? 1 : 0
  manifest = yamldecode(templatefile(local.hpa_custom_metric_template, {
    namespace               = var.namespace
    hpa_type                = try(var.hpa_type, "")
    hpa_averagevalue_target = try(var.hpa_averagevalue_target, 1)
    hpa_min_replicas        = var.hpa_min_replicas
    hpa_max_replicas        = var.hpa_max_replicas
  }))
}
