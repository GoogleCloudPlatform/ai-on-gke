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

## BEFORE APPLYING TEMPLATES

# 1) Assure that we need to upload the new data point if either there is none of the existing one is unsatisfactory
# 2) Use the `catalog generate` tool to generate the manifests and pipe them to `kubectl apply -f`, assure kubectl succeeds


resource "google_project_service" "cloudbuild" {
  count = var.build_latency_profile_generator_image ? 1 : 0
  project = var.project_id
  service = "cloudbuild.googleapis.com"

  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_on_destroy = false
}

module "latency-profile" {
  source = "../latency-profile"

  credentials_config                         = var.credentials_config
  namespace                                  = var.namespace
  project_id                                 = var.project_id
  ksa                                        = var.ksa
  templates_path                             = var.templates_path
  artifact_registry                          = var.artifact_registry
  build_latency_profile_generator_image      = false
  inference_server_service                   = var.inference_server_service
  inference_server_service_port              = var.inference_server_service_port
  inference_server_framework                 = var.inference_server_framework
  max_num_prompts                            = var.max_num_prompts
  max_output_len                             = var.max_output_len
  max_prompt_len                             = var.max_prompt_len
  request_rates                              = var.request_rates
  tokenizer                                  = var.tokenizer
  output_bucket                              = var.output_bucket
  latency_profile_kubernetes_service_account = var.latency_profile_kubernetes_service_account
  k8s_hf_secret                              = var.k8s_hf_secret
  hugging_face_secret                        = var.hugging_face_secret
  hugging_face_secret_version                = var.hugging_face_secret_version
}