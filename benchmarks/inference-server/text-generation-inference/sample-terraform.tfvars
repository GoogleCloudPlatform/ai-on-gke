credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/global/gkeMemberships/ai-benchmark"
}

project_id = "$PROJECT_ID"

namespace = "benchmark"
ksa       = "benchmark-ksa"
model_id  = "tiiuae/falcon-7b"
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

# Sets the averagevalue target of the hpa metric.
#
# e.g for cpu scaling, this is the cpu utilization, expressed as a value
# between 0-100. 50 is a reasonable starting point.
#hpa_averagevalue_target = 50
#
# For tgi_batch_current_size, try 10. (TODO: experiment with this to determine
# optimal values).
#hpa_averagevalue_target = 10

# Adjust these if you want different min/max values
# hpa_min_replicas = 1
# hpa_max_replicas = 5
