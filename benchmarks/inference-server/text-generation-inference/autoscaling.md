# Autoscaling TGI

## tl;dr

Recommendation: TODO

## Autoscaling Options

### CPU

CPU scaling is a poor choice for this workload - the TGI workload starts up,
pulls the model weights, and then spends a minute or two worth of cpu time
crunching some numbers. This causes hpa to add a replica, which then spends
more cpu time, which causes hpa to add a replica, etc. Eventually, things
settle, and hpa scales down the replicas. This whole process could take up to
an hour.

### Custom Metrics

Workload/custom metrics can be viewed in
https://console.cloud.google.com/monitoring/metrics-explorer. (Just search for
the metric name, e.g. "tgi_batch_current_size". The full name should be
"prometheus/tgi_batch_current_size/gauge")

#### `tgi_batch_current_size`

TODO

### External Metrics

TODO
