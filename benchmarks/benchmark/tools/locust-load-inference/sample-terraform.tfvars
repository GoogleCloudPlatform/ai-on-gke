credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUM/locations/global/gkeMemberships/ai-benchmark"
}

project_id = "change-me"

namespace = "benchmark"
ksa       = "benchmark-ksa"

# Locust service configuration 
artifact_registry                        = "us-central1-docker.pkg.dev/$PROJECT_ID/ai-benchmark"
inference_server_service                 = "tgi" # inference server service name
locust_runner_kubernetes_service_account = "sample-runner-ksa"
output_bucket                            = "benchmark-output"
gcs_path                                 = "gs://ai-on-gke-benchmark/ShareGPT_V3_unfiltered_cleaned_split_filtered_prompts.txt"

# Benchmark configuration for Locust Docker accessing inference server
inference_server_framework = "tgi"
tokenizer                  = "tiiuae/falcon-7b"

# Benchmark configuration for triggering single test via Locust Runner
test_duration = 600
test_users    = 1
test_rate     = 5