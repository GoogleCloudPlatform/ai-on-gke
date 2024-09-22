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

  hpa_custom_metric_template = "${path.module}/hpa-templates/hpa.vllm.custom_metric.yaml.tftpl"
  use_vllm_metrics_for_hpa   = var.hpa_type == null ? false : length(regexall("vllm.*", var.hpa_type)) > 0
  custom_metrics_enabled     = local.use_vllm_metrics_for_hpa


  all_templates = concat(local.wl_templates, local.secret_templates)

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
  vllm_podmonitoring = "${path.module}/monitoring-templates/vllm-podmonitoring.yaml.tftpl"
}

resource "kubernetes_manifest" "default" {
  for_each = toset(local.all_templates)
  manifest = yamldecode(templatefile(each.value, {
    namespace                      = var.namespace
    model_id                       = var.model_id
    gpu_count                      = var.gpu_count
    swap_space                     = var.swap_space
    ksa                            = var.ksa
    hugging_face_token_secret_list = local.hugging_face_token_secret == null ? [] : [local.hugging_face_token_secret]
  }))
  timeouts {
    create = "60m"
  }
}

resource "kubernetes_manifest" "vllm-pod-monitoring" {
  manifest = yamldecode(templatefile(local.vllm_podmonitoring, {
    namespace = var.namespace
  }))
}

module "custom_metrics_stackdriver_adapter" {
  count  = local.custom_metrics_enabled ? 1 : 0
  source = "../../../modules/custom-metrics-stackdriver-adapter"
  workload_identity = {
    enabled    = true
    project_id = var.project_id
  }
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
