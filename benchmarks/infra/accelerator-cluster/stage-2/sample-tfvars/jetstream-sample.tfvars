# can be obtained from stage-1 by running:
# terraform output -json  | jq '."fleet_host".value'
credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/global/gkeMemberships/ai-benchmark"
}

# can be obtained from stage-1 by running:
# terraform output -json  | jq '."project_id".value'
project_id = "PROJECT_ID"

bucket_name     = "${PROJECT_ID}-model-repo-bucket-01"
bucket_location = "US"

output_bucket_name     = "${PROJECT_ID}-benchmark-output-bucket-01"
output_bucket_location = "US"

google_service_account     = "benchmark-sa-01"
kubernetes_service_account = "benchmark-sa"

benchmark_runner_google_service_account     = "sample-runner-sa-01"
benchmark_runner_kubernetes_service_account = "sample-runner-sa"

nvidia_dcgm_create = "false"
namespace          = "default"
namespace_create   = false
gcs_fuse_create    = true

