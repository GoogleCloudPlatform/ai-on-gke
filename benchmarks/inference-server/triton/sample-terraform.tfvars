credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/global/gkeMemberships/ai-benchmark"
}

namespace      = "benchmark"
ksa            = "benchmark-ksa"
model_id       = "meta-llama/Llama-2-7b-chat-hf"
gpu_count      = 1
gcs_model_path = ""