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
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUM/locations/global/gkeMemberships/ai-benchmark"
}

project_id = "$PROJECT_ID"

namespace = "benchmark"

k8s_hf_secret = "hf-token"

# Latency profile generator service configuration
latency_profile_kubernetes_service_account = "sample-runner-ksa"
output_bucket                              = "${PROJECT_ID}-benchmark-output"
gcs_path                                   = "gs://${PROJECT_ID}-ai-gke-benchmark-fuse/ShareGPT_V3_unfiltered_cleaned_split_filtered_prompts.txt"

# Inference server configuration
inference_server = {
  deploy    = false
  name      = "tgi"
  tokenizer = "tiiuae/falcon-7b"
  service = {
    name = "tgi", # inference server service name
    port = 8000
  }
}

# Benchmark configuration for Latency Profile Generator container accessing inference server
request_rates          = [5, 10, 15, 20]
benchmark_time_seconds = 120