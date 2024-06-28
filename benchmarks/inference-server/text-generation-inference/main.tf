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

  all_templates = concat(local.wl_templates, local.secret_templates)

  hpa_cpu_template           = "${path.module}/hpa-templates/hpa.cpu.yaml.tftpl"
  hpa_custom_metric_template = "${path.module}/hpa-templates/hpa.tgi.custom_metric.yaml.tftpl"
  tgi_podmonitoring          = "${path.module}/monitoring-templates/tgi-podmonitoring.yaml.tftpl"
  dcgm_podmonitoring_for_hpa = "${path.module}/hpa-templates/dcgm-podmonitoring.yaml.tftpl"
  use_dcgm_metrics_for_hpa   = var.hpa_type == null ? false : length(regexall("DCGM_.*", var.hpa_type)) > 0
  use_tgi_metrics_for_hpa    = var.hpa_type == null ? false : length(regexall("tgi_.*", var.hpa_type)) > 0
  custom_metrics_enabled     = local.use_dcgm_metrics_for_hpa || local.use_tgi_metrics_for_hpa

  wl_templates = [
    for f in fileset(local.wl_templates_path, "*tftpl") :
    "${local.wl_templates_path}/${f}"
  ]

  secret_templates = local.hugging_face_token_secret == null ? [] : [
    for f in fileset(local.secret_templates_path, "*tftpl") :
    "${local.secret_templates_path}/${f}"
  ]

  wl_templates_path = (
    var.templates_path == null
    ? "${path.module}/manifest-templates"
    : pathexpand(var.templates_path)
  )
  secret_templates_path = (
    var.secret_templates_path == null
    ? "${path.module}/../templates/secret-templates"
    : pathexpand(var.secret_templates_path)
  )
  hugging_face_token_secret = (
    var.hugging_face_secret == null || var.hugging_face_secret_version == null
    ? null
    : "${var.hugging_face_secret}/versions/${var.hugging_face_secret_version}"
  )
}

module "custom_metrics_stackdriver_adapter" {
  count  = local.custom_metrics_enabled ? 1 : 0
  source = "../../../modules/custom-metrics-stackdriver-adapter"
  workload_identity = {
    enabled    = true
    project_id = var.project_id
  }
}

resource "kubernetes_manifest" "default" {
  for_each = toset(local.all_templates)
  manifest = yamldecode(templatefile(each.value, {
    namespace                      = var.namespace
    model_id                       = var.model_id
    gpu_count                      = var.gpu_count
    max_concurrent_requests        = var.max_concurrent_requests
    ksa                            = var.ksa
    hugging_face_token_secret_list = local.hugging_face_token_secret == null ? [] : [local.hugging_face_token_secret]
  }))
  timeouts {
    create = "60m"
  }
}

resource "kubernetes_manifest" "hpa-cpu" {
  count = var.hpa_type == "cpu" ? 1 : 0
  manifest = yamldecode(templatefile(local.hpa_cpu_template, {
    namespace               = var.namespace
    hpa_averagevalue_target = var.hpa_averagevalue_target
    hpa_min_replicas        = var.hpa_min_replicas
    hpa_max_replicas        = var.hpa_max_replicas
  }))
}

resource "kubernetes_manifest" "tgi-pod-monitoring" {
  manifest = yamldecode(templatefile(local.tgi_podmonitoring, {
    namespace = var.namespace
  }))
}

resource "kubernetes_manifest" "dcgm-pod-monitoring-for-hpa" {
  count = local.use_dcgm_metrics_for_hpa ? 1 : 0
  manifest = yamldecode(templatefile(local.dcgm_podmonitoring_for_hpa, {
    custom_metric_name = var.hpa_type
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
