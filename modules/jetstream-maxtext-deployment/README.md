## Bash equivalent of this module

Assure the following are set before running:
   - MODEL_NAME: The name of your LLM (as of the writing of this README valid options are "gemma-7b", "llama2-7b", "llama2-13b")
   - PARAMETERS_PATH: Where to find the parameters for your LLM (if using the checkpoint-converter it will be "gs:\/\/$BUCKET_NAME\/final\/unscanned\/gemma_7b-it\/0\/checkpoints\/0\/items" where $BUCKET_NAME is the same one used in the checkpoint-converter)
   - METRICS_PORT: Port to emit custom metrics on
   - (optional) TPU_TOPOLOGY: Topology of TPU chips used by jetstream (default: "2x4")
   - (optional) TPU_TYPE: Type of TPUs used (default: "tpu-v5-lite-podslice")
   - (optional) TPU_CHIP_COUNT: Number of TPU chips requested, can be obtained by algebraically evaluating TPU_TOPOLOGY
   - (optional) MAXENGINE_SERVER_IMAGE: Maxengine server container image
   - (optional) JETSTREAM_HTTP_SERVER_IMAGE: Jetstream HTTP server container image

```
if [ -z "$MAXENGINE_SERVER_IMAGE" ]; then
    MAXENGINE_SERVER_IMAGE="us-docker.pkg.dev\/cloud-tpu-images\/inference\/maxengine-server:v0.2.2"
fi

if [ -z "$JETSTREAM_HTTP_SERVER_IMAGE" ]; then
    JETSTREAM_HTTP_SERVER_IMAGE="us-docker.pkg.dev\/cloud-tpu-images\/inferenc\/jetstream-http:v0.2.2"
fi

if [ -z "$TPU_TOPOLOGY" ]; then
    TPU_TOPOLOGY="2x4"
fi

if [ -z "$TPU_TYPE" ]; then
    TPU_TYPE="tpu-v5-lite-podslice"
fi

if [ -z "$TPU_CHIP_COUNT" ]; then
    TPU_CHIP_COUNT="8"
fi

if [ -z "$MODEL_NAME" ]; then
    echo "Must provide MODEL_NAME in environment" 1>&2
    exit 2;
fi

if [ -z "$PARAMETERS_PATH" ]; then
    echo "Must provide PARAMETERS_PATH in environment" 1>&2
    exit 2;
fi

JETSTREAM_MANIFEST=$(mktemp)
cat ./templates/deployment.yaml.tftpl >> "$JETSTREAM_MANIFEST"

PODMONITORING_MANIFEST=$(mktemp)
cat ./templates/podmonitoring.yaml.tftpl >> "$PODMONITORING_MANIFEST"

if [ "$METRICS_PORT" != "" ]; then
    cat $PODMONITORING_MANIFEST | sed "s/\${metrics_port}/$METRICS_PORT/g" >> "$PODMONITORING_MANIFEST"
    cat $JETSTREAM_MANIFEST | sed "s/\${metrics_port_arg}/prometheus_port=$METRICS_PORT/g" >> "$JETSTREAM_MANIFEST"
    
    cat $PODMONITORING_MANIFEST | kubectl apply -f -
else
    cat $JETSTREAM_MANIFEST | sed "s/\${metrics_port_arg}//g" >> "$JETSTREAM_MANIFEST"
fi

cat $JETSTREAM_MANIFEST \
| sed "s/\${tpu-type}/$TPU_TYPE/g" \
| sed "s/\${tpu-topology}/$TPU_TOPOLOGY/g" \
| sed "s/\${tpu-chip-count}/$TPU_CHIP_COUNT/g" \
| sed "s/\${maxengine_server_image}/$MAXENGINE_SERVER_IMAGE/g" \
| sed "s/\${jetstream_http_server_image}/$JETSTREAM_HTTP_SERVER_IMAGE/g" \
| sed "s/\${model_name}/$MODEL_NAME/g" \
| sed "s/\${load_parameters_path_arg}/$PARAMETERS_PATH/g" >> "$JETSTREAM_MANIFEST"

cat $JETSTREAM_MANIFEST | kubectl apply -f -
```

### Metrics Adapter

#### Custom Metrics Stackdriver Adapter

Follow the [Custom-metrics-stackdriver-adapter README](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/main/modules/custom-metrics-stackdriver-adapter/README.md) to install without terraform

Once installed the following metrics can be used as averageValues in a HorisontalPodAutoscaler (HPA):
  - Jetstream metrics (i.e. any metric prefixed with "jetstream_")
  - "memory_used" (the current sum of memory usage across all accelerators used by a node in bytes)

#### Prometheus Adapter

Follow the [Prometheus-adapter README](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/main/modules/prometheus-adapter/README.md) to install without terraform, a few notes:

This module requires the cluster name to be passed in manually via the CLUSTER_NAME variable to filter incoming metrics. This is a consequence of differing cluster name schemas between GKE and standard k8s clusters. Instructions for each are as follows for if the cluster name isnt already known. For GKE clusters, Remove any characters prior to and including the last underscore with `kubectl config current-context | awk -F'_' ' { print $NF }'` to get the cluster name. For other clusters, The cluster name is simply: `kubectl config current-context`.

Instructions to set the PROMETHEUS_HELM_VALUES_FILE env var as follows:

```
PROMETHEUS_HELM_VALUES_FILE=$(mktemp)
sed "s/\${cluster_name}/$CLUSTER_NAME/g" ../templates/values.yaml.tftpl >> "$PROMETHEUS_HELM_VALUES_FILE"
```

Once installed the following metrics can be used as averageValues in a HorisontalPodAutoscaler (HPA):
  - Jetstream metrics (i.e. any metric prefixed with "jetstream_")
  - "accelerator_memory_used_percentage" (the percentage of total accelerator memory used across all accelerators used by a node)

