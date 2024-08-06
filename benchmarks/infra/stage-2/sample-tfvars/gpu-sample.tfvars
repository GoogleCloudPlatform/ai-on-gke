# can be obtained from stage-1 by running:
# terraform output -json  | jq '."fleet_host".value'
credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/global/gkeMemberships/ai-benchmark"
}

# can be obtained from stage-1 by running:
# terraform output -json  | jq '."project_id".value'
project_id = "$PROJECT_ID"

bucket_name     = "${PROJECT_ID}-ai-gke-benchmark-fuse"
bucket_location = "US"

output_bucket_name     = "${PROJECT_ID}-benchmark-output"
output_bucket_location = "US"

google_service_account     = "benchmark-sa"
kubernetes_service_account = "benchmark-ksa"

benchmark_runner_google_service_account     = "sample-runner-sa"
benchmark_runner_kubernetes_service_account = "sample-runner-ksa"
