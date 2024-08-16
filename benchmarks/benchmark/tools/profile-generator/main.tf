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

module "latency-profile" {
  source = "../latency-profile"

  credentials_config                         = var.credentials_config
  namespace                                  = var.namespace
  project_id                                 = var.project_id
  ksa                                        = var.ksa
  templates_path                             = var.templates_path
  artifact_registry                          = var.artifact_registry
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