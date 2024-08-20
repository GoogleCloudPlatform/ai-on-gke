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
  templates = [
    for f in fileset(local.templates_path, "*tpl") :
    "${local.templates_path}/${f}"
  ]
  templates_path = (
    var.templates_path == null
    ? "${path.module}/manifest-templates"
    : pathexpand(var.templates_path)
  )
  hugging_face_token_secret = (
    var.hugging_face_secret == null || var.hugging_face_secret_version == null
    ? null
    : "${var.hugging_face_secret}/versions/${var.hugging_face_secret_version}"
  )

  all_manifests = flatten([for manifest_file in local.templates :
    [for data in split("---", templatefile(manifest_file, {
      combo                                      = format("%s-%s-%s-%s", var.inference_server.name, var.inference_server.model, var.inference_server.accelerator_config.type, var.inference_server.accelerator_config.count)
      artifact_registry                          = var.artifact_registry
      namespace                                  = var.namespace
      inference_server_framework                 = var.inference_server.name
      inference_server_service                   = var.inference_server.service.name
      inference_server_service_port              = var.inference_server.service.port
      tokenizer                                  = var.inference_server.tokenizer
      ksa                                        = var.ksa
      latency_profile_kubernetes_service_account = var.latency_profile_kubernetes_service_account
      max_num_prompts                            = var.max_num_prompts
      max_output_len                             = var.max_output_len
      max_prompt_len                             = var.max_prompt_len
      request_rates                              = join(",", [for number in var.request_rates : tostring(number)])
      hugging_face_token_secret_list             = local.hugging_face_token_secret == null ? [] : [local.hugging_face_token_secret]
      k8s_hf_secret_list                         = var.k8s_hf_secret == null ? [] : [var.k8s_hf_secret]
      output_bucket                              = var.output_bucket
    })) : data]
  ])
}

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

data "google_client_config" "identity" {
  count = var.credentials_config.fleet_host != null ? 1 : 0
}


resource "google_project_service" "cloudbuild" {
  count   = var.build_latency_profile_generator_image ? 1 : 0
  project = var.project_id
  service = "cloudbuild.googleapis.com"

  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_on_destroy = false
}

resource "null_resource" "deploy_model_server" {
  count = var.inference_server.deploy ? 1 : 0
  provisioner "local-exec" {
    command = "echo hello"
  }
  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "kubernetes_manifest" "deploy_latency_profile_generator" {
  for_each   = toset(local.all_manifests)
  depends_on = [resource.null_resource.build_and_push_image, resource.null_resource.deploy_model_server]
  manifest   = yamldecode(each.value)
  timeouts {
    create = "30m"
  }
}

resource "null_resource" "cleanup_model_server" {
  depends_on = [resource.kubernetes_manifest.deploy_latency_profile_generator]
  provisioner "local-exec" {
    command = "kubectl wait --for=condition=complete job/latency-profile-generator --timeout=-9600s && echo hello"
  }
  triggers = {
    always_run = "${timestamp()}"
  }
}