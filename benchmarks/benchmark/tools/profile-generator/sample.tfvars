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

credentials_config = {
  kubeconfig = {
    path = "~/.kube/config"
  }
}

project_id = "tpu-vm-gke-testing"


# Latency profile generator service configuration
artifact_registry                          = "us-central1-docker.pkg.dev/tpu-vm-gke-testing/ai-benchmark"
build_latency_profile_generator_image      = false
latency_profile_kubernetes_service_account = "prom-frontend-sa"
output_bucket                              = "tpu-vm-gke-testing-benchmark-output-bucket"
k8s_hf_secret                              = "hf-token"

# Inference server configuration
inference_server = {
  deploy = false
  name = "jetstream"
  tokenizer = "google/gemma-7b"
  service = {
    name = "maxengine-server", # inference server service name
    port = 8000
  }
}

# Benchmark configuration for Locust Docker accessing inference server
request_rates              = [5, 10, 15, 20]

profiles = {
  valid_models = [
    "gemma2-2b",
    "gemma2-9b",
    "gemma2-27b",
    "llama3-8b",
    "llama3-70b",
    "llama3-405b"
  ]
  valid_accelerators = [
    "tpu-v4-podslice",
    "tpu-v5-lite-podslice",
    "tpu-v5p-slice",
    "nvidia-a100-80gb",
    "nvidia-h100-80gb",
    "nvidia-l4"
  ]
  request_rates = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]

  config = [{
    model_server = "Jetstream"
    model_server_configs = [{
      models = [
        "gemma2-2b",
        "gemma2-9b",
        "gemma2-27b"
      ]
      model_configs = []
    }]
    }, {
    model_server = "vllm"
    model_server_configs = [{
      models = [
        "gemma2-2b",
        "gemma2-9b",
        "gemma2-27b",
        "llama3-8b",
        "llama3-70b",
        "llama3-405b"
      ]
      model_configs = []
    }]
    }, {
    model_server = "tgi"
    model_server_configs = [{
      models = [
        "gemma2-2b",
        "gemma2-9b",
        "gemma2-27b",
        "llama3-8b",
        "llama3-70b",
        "llama3-405b"
      ]
      model_configs = []
    }]
    }, {
    model_server = "tensorrt-llm"
    model_server_configs = [{
      models = [
        "llama3-8b",
        "llama3-70b",
        "llama3-405b"
      ]
      model_configs = []
    }]
  }]
}