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
build_latency_profile_generator_image      = false
latency_profile_kubernetes_service_account = "prom-frontend-sa"
output_bucket                              = "tpu-vm-gke-testing-benchmark-output-bucket"
k8s_hf_secret                              = "hf-token"

# Benchmark configuration for Locust Docker accessing inference server
request_rates = [5, 10, 15, 20]

targets = {
  manual = {
    name = 'your-model-server-name'
    service_name = 'your-model-server-service-name'
    service_port = 'your-model-service-service-port'
    tokenizer = 'your-tokenizer'
  }
}
