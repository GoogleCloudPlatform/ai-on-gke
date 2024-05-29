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
  custom_metrics_enabled     = var.custom_metrics_enabled
}

module "custom_metrics_stackdriver_adapter" {
  count  = local.custom_metrics_enabled ? 1 : 0
  source = "./custom-metrics-stackdriver-adapter"
  workload_identity = {
    enabled    = true
    project_id = var.project_id
  }
}

resource "kubernetes_manifest" "tgi-pod-monitoring" {
  manifest = yamldecode(templatefile(local.jetstream_podmonitoring, {
    namespace = var.namespace
  }))
}

resource "kubernetes_manifest" "hpa_custom_metric" {
  count = local.custom_metrics_enabled ? 1 : 0
  manifest = yamldecode(templatefile(local.hpa_custom_metric_template, {
    namespace               = var.namespace
    custom_metric_name      = var.hpa_type
    hpa_averagevalue_target = var.hpa_averagevalue_target
    hpa_min_replicas        = var.hpa_min_replicas
    hpa_max_replicas        = var.hpa_max_replicas
  }))
}
