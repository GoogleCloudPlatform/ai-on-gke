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
  template_path = var.gcs_model_path == null ? "${path.module}/manifest-templates/triton-tensorrtllm-inference-docker.tftpl" : "${path.module}/manifest-templates/triton-tensorrtllm-inference-gs.tftpl"
}

resource "kubernetes_manifest" "default" {
  manifest = yamldecode(templatefile(local.template_path, {
    namespace                    = var.namespace
    ksa                          = var.ksa
    image_path                   = var.image_path
    huggingface-secret           = var.huggingface-secret
    gpu_count                    = var.gpu_count
    model_id                     = var.model_id
    gcs_model_path               = var.gcs_model_path
    server_launch_command_string = var.server_launch_command_string
  }))
}
