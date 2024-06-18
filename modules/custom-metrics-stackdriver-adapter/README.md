# Custom Metrics Stackdriver Adapter

Adapted from https://raw.githubusercontent.com/GoogleCloudPlatform/k8s-stackdriver/master/custom-metrics-stackdriver-adapter/deploy/production/adapter_new_resource_model.yaml

## Usage

To use this module, include it from your main terraform config, i.e.:

```
module "custom_metrics_stackdriver_adapter" {
  source = "./path/to/custom-metrics-stackdriver-adapter"
}
```

For a workload identity enabled cluster, some additional configuration is
needed:

```
module "custom_metrics_stackdriver_adapter" {
  source = "./path/to/custom-metrics-stackdriver-adapter"
  workload_identity = {
    enabled = true
    project_id = "<PROJECT_ID>"
  }
}
```