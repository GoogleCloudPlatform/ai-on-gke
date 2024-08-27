credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUM/locations/global/gkeMemberships/ai-benchmark"
}

project_id = "$PROJECT_ID"

namespace = "benchmark"
ksa       = "benchmark-ksa"


# This is needed for loading the gated models on HF
# k8s_hf_secret = "hf-token"

# Locust service configuration 
artifact_registry                        = "us-central1-docker.pkg.dev/$PROJECT_ID/ai-benchmark"
inference_server_service                 = "tgi" # inference server service name
locust_runner_kubernetes_service_account = "sample-runner-ksa"
output_bucket                            = "${PROJECT_ID}-benchmark-output"
gcs_path                                 = "gs://${PROJECT_ID}-ai-gke-benchmark-fuse/ShareGPT_V3_unfiltered_cleaned_split_filtered_prompts.txt"

# Benchmark configuration for Locust Docker accessing inference server
inference_server_framework = "tgi"
tokenizer                  = "tiiuae/falcon-7b"

# Benchmark configuration for triggering single test via Locust Runner
test_duration = 60
# Increase test_users to allow more parallelism (especially when testing HPA)
test_users = 1
test_rate  = 5

stop_timeout = 10800