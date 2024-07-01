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
  deployment_template         = "${path.module}/templates/deployment.yaml.tftpl"
  service_template            = "${path.module}/templates/service.yaml.tftpl"
  podmonitoring_template      = "${path.module}/templates/podmonitoring.yaml.tftpl"
  cmsa_jetstream_hpa_template = "${path.module}/templates/custom-metrics-stackdriver-adapter/hpa.jetstream.yaml.tftpl"
}

resource "kubernetes_manifest" "jetstream-deployment" {
  count = 1
  manifest = yamldecode(templatefile(local.deployment_template, {
    maxengine_server_image      = var.maxengine_server_image
    jetstream_http_server_image = var.jetstream_http_server_image
    load_parameters_path_arg    = format("load_parameters_path=gs://%s/final/unscanned/gemma_7b-it/0/checkpoints/0/items", var.bucket_name)
    metrics_port_arg            = var.metrics_port != null ? format("prometheus_port=%d", var.metrics_port) : "",
  }))
}

resource "kubernetes_manifest" "jetstream-service" {
  count    = 1
  manifest = yamldecode(file(local.service_template))
}

resource "kubernetes_manifest" "jetstream-podmonitoring" {
  count = var.metrics_port != null ? 1 : 0
  manifest = yamldecode(templatefile(local.podmonitoring_template, {
    metrics_port = var.metrics_port != null ? var.metrics_port : "",
  }))
}

module "custom_metrics_stackdriver_adapter" {
  count  = var.metrics_adapter == "custom-metrics-stackdriver-adapter" ? 1 : 0
  source = "../custom-metrics-stackdriver-adapter"
  workload_identity = {
    enabled    = true
    project_id = var.project_id
  }
}

## Prometheus adapter deployment pending https://github.com/GoogleCloudPlatform/ai-on-gke/pull/716/files merge


resource "kubernetes_manifest" "hpa_custom_metric" {
  count = (var.custom_metrics_enabled && var.hpa_type != null || var.hpa_type != "memory_used") && var.hpa_averagevalue_target != null ? 1 : 0
  manifest = yamldecode(templatefile(local.cmsa_jetstream_hpa_template, {
    hpa_type                = try(var.hpa_type, "")
    hpa_averagevalue_target = try(var.hpa_averagevalue_target, 1)
    hpa_min_replicas        = var.hpa_min_replicas
    hpa_max_replicas        = var.hpa_max_replicas
  }))
}
