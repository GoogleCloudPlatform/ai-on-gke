maxengine_deployment_settings = {
  metrics_port            = 9100
  metrics_scrape_interval = 10
  accelerator_selectors = {
    topology    = "2x4"
    accelerator = "tpu-v5-lite-podslice"
    chip_count : 8
  }
}

# Demonstrating autoscaling with jetstream_prefill_backlog_size, change as desired.
# For jetstream_prefill_backlog_size. (experiment with this to determine optimal values).

# hpa_config = {
#   metrics_adapter = "prometheus-adapter"
#   max_replicas    = 5
#   min_replicas    = 1
#   rules = [{
#     target_query         = "jetstream_prefill_backlog_size"
#     average_value_target = 5
#   }]
# }