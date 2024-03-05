credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/global/gkeMemberships/ai-benchmark"
}

namespace = "benchmark"
ksa       = "benchmark-ksa"
model_id  = "tiiuae/falcon-7b"
gpu_count = 1

# How to (horizontally) scale the workload. Allowed values are:
# - null (no scaling),
# - "cpu" (scale on cpu utilization).
# - Other possibilities coming soon...
#
# Note: "cpu" scaling is a poor choice for this workload - the tgi workload
# starts up, pulls the model weights, and then spends a minute or two worth of
# cpu time crunching some numbers. This causes hpa to add a replica, which then
# spends more cpu time, which causes hpa to add a replica, etc. Eventually,
# things settle, and hpa scales down the replicas. This whole process could
# take up to an hour.
hpa_type = null

# Adjust these if you want different min/max values
# hpa_min_replicas = 1
# hpa_max_replicas = 5
