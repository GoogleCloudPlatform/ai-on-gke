credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/global/gkeMemberships/ai-benchmark"
}

namespace = "benchmark"
ksa  = "benchmark-ksa"
model_id = "tiiuae/falcon-7b"
gpu_count = 1

# How to (horizontally) scale the workload. Allowed values are:
# - null (no scaling),
# - Workload resources:
#   - "cpu" (scale on cpu utilization).
# - Workload metrics (i.e. custom metrics):
#   - "tgi_queue_size"
#   - "tgi_batch_current_size"
#   - "tgi_batch_current_max_tokens"
# - Other possibilities coming soon...
#
# See `autoscaling.md` for more details and recommendations.
hpa_type = null

# Sets the averagevalue target of the hpa metric. e.g for cpu scaling, this is
# the cpu utilization, expressed as a value between 0-100.
hpa_averagevalue_target = 123  # TODO: Experiment with this to determine optimal values

project_id = "<project_id>"
