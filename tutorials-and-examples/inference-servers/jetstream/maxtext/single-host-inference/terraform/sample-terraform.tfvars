maxengine_deployment_settings = {
    custom_metrics_enabled = true
    metrics_port           = 9100
    accelerator_selectors = {
      topology = "2x4"
      accelerator = "tpu-v5-lite-podslice"
      chip_count: 8
    }
}

hpa_config = {
  metrics_adapter = "prometheus-adapter"
  max_replicas = 5
  min_replicas = 1
  rules = [ {
    target_query = "jetstream_prefill_backlog_size"
    average_value_target = 5
  } ]
}