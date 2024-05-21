credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/PROJECT_NUMBER/locations/global/gkeMemberships/ai-benchmark"
}

project_id = "PROJECT_ID"

namespace    = "default"
ksa          = "benchmark-sa"
request_type = "grpc"

k8s_hf_secret = "hf-token"


# Locust service configuration 
artifact_registry                        = "REGISTRY_LOCATION"
inference_server_service                 = "jetstream-svc:9000"
locust_runner_kubernetes_service_account = "sample-runner-sa"
output_bucket                            = "${PROJECT_ID}-benchmark-output-bucket-01"
gcs_path                                 = "PATH_TO_PROMPT_BUCKET"

# Benchmark configuration for Locust Docker accessing inference server
inference_server_framework = "jetstream"
tokenizer                  = "google/gemma-7b"

# Benchmark configuration for triggering single test via Locust Runner
test_duration = 60
# Increase test_users to allow more parallelism (especially when testing HPA)
test_users = 1
test_rate  = 5
