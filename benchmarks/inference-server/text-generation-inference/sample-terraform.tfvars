credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/global/gkeMemberships/ai-benchmark"
}

namespace = "benchmark"
ksa       = "benchmark-ksa"
model_id  = "tiiuae/falcon-7b"
gpu_count = 1