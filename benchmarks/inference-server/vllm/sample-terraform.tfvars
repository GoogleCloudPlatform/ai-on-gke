credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/global/gkeMemberships/ai-benchmark"
}

namespace  = "benchmark"
ksa        = "benchmark-ksa"
model_id   = "tiiuae/falcon-7b"
gpu_count  = 1
project_id = "<project_id>"

# How to (horizontally) scale the workload. Allowed values are:
# - Workload metrics (i.e. custom metrics):
#   - "vllm:gpu_cache_usage_perc"
#   - "vllm:num_requests_waiting"
# - Other possibilities coming soon...
#
# See `autoscaling.md` for more details and recommendations.
# hpa_type = "vllm:gpu_cache_usage_perc"

# Sets the averagevalue target of the hpa metric.
# hpa_averagevalue_target = 0.95

# Adjust these if you want different min/max values
# hpa_min_replicas = 1
# hpa_max_replicas = 5