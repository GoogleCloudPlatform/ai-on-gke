This module deploys Jetstream Maxtext to a cluster. If `prometheus_port` is set then a [PodMontoring CR](https://cloud.google.com/stackdriver/docs/managed-prometheus/setup-managed#gmp-pod-monitoring) will be deployed for scraping metrics and exporting them to Google Cloud Monitoring. See the [deployment template](./templates/deployment.yaml.tftpl) to see which command line args are passed by default. For additional configuration please reference the [MaxText base config file](https://github.com/google/maxtext/blob/main/MaxText/configs/base.yml) for a list of configurable command line args and their explainations.

## Installation via bash and kubectl

Assure the following environment variables are set:
   - MODEL_NAME: The name of your LLM (as of the writing of this README valid options are "gemma-7b", "llama2-7b", "llama2-13b")
   - PARAMETERS_PATH: Where to find the parameters for your LLM (if using the checkpoint-converter it will be "gs:\/\/$BUCKET_NAME\/final\/unscanned\/gemma_7b-it\/0\/checkpoints\/0\/items" where $BUCKET_NAME is the same one used in the checkpoint-converter)
   - (optional) METRICS_PORT: Port to emit custom metrics on
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

if [ "$MODEL_NAME" = "gemma-7b"  ]; then
    TOKENIZER="assets/tokenizer.gemma"
elif [ "$MODEL_NAME" = "llama2-7b" ] || [ "$MODEL_NAME" = "llama2-13b" ]; then
    TOKENIZER="assets/tokenizer.llama2"
else
    echo "Must provide valid MODEL_NAME in environment, valid options include 'gemma-7b', 'llama2-7b', 'llama2-13b'" 1>&2
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
| sed "s/\${tokenizer}/$TOKENIZER/g" \
| sed "s/\${load_parameters_path_arg}/$PARAMETERS_PATH/g" >> "$JETSTREAM_MANIFEST"

cat $JETSTREAM_MANIFEST | kubectl apply -f -
```
## (Optional) Autoscaling Components

Applying the following resources to your cluster will enable you to scale the number of Jetstream server pods with custom or system metrics:
 - Metrics Adapter (either [Prometheus-adapter](https://github.com/kubernetes-sigs/prometheus-adapter)(recommended) or [CMSA](https://github.com/GoogleCloudPlatform/k8s-stackdriver/tree/master/custom-metrics-stackdriver-adapter)): For making metrics from the Google Cloud Monitoring API visible to resources within the cluster.
 - [Horizontal Pod Autoscaler (HPA)](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/): For reading metrics and setting the maxengine-servers deployments replica count accordingly.

### Metrics Adapter

#### Custom Metrics Stackdriver Adapter

Follow the [Custom-metrics-stackdriver-adapter README](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/main/modules/custom-metrics-stackdriver-adapter/README.md) to install without terraform.

Once installed the values of the following metrics can be used as averageValues in a HorizontalPodAutoscaler (HPA):
  - Jetstream metrics (i.e. any metric prefixed with "jetstream_")
  - "memory_used" (the current sum of memory usage across all accelerators used by a node in bytes, note this value can be extremely large since the unit of measurement is bytes)

#### Prometheus Adapter

Follow the [Prometheus-adapter README](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/main/modules/prometheus-adapter/README.md) to install without terraform. A few notes:

This module uses the the prometheus-community/prometheus-adapter Helm chart as part of the install process, it has a values file that requires "CLUSTER_NAME" to be replaced with your cluster name in order to properly filter metrics. This is a consequence of differing cluster name schemes between GKE and standard k8s clusters. Instructions for each are as follows for if the cluster name isnt already known. For GKE clusters, Remove any characters prior to and including the last underscore with `kubectl config current-context | awk -F'_' ' { print $NF }'` to get the cluster name. For other clusters, The cluster name is simply: `kubectl config current-context`.

Instructions to set the PROMETHEUS_HELM_VALUES_FILE env var as follows:

```
PROMETHEUS_HELM_VALUES_FILE=$(mktemp)
sed "s/\${cluster_name}/$CLUSTER_NAME/g" ../templates/values.yaml.tftpl >> "$PROMETHEUS_HELM_VALUES_FILE"
```

Once installed the values of the following metrics can be used as averageValues in a HorizontalPodAutoscaler (HPA):
  - Jetstream metrics (i.e. any metric prefixed with "jetstream_")
  - "memory_used_percentage" (the percentage of total accelerator memory used across all accelerators used by a node)

### Horizontal Pod Autoscalers

The following should be run for each HPA, assure the following are set before running:
 - ADAPTER: The adapter currently in cluster, can be either 'custom-metrics-stackdriver-adapter' or 'prometheus-adapter'
 - MIN_REPLICAS: Lower bound for number of jetstream replicas
 - MAX_REPLICAS: Upper bound for number of jetstream replicas
 - METRIC: The metrics whose value will be compared against the average value, can be any metric listed above
 - AVERAGE_VALUE: Average value to be used for calculating replica cound, see [docs](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#algorithm-details) for more details
 
 ```
if [ -z "$ADAPTER" ]; then
    echo "Must provide ADAPTER in environment" 1>&2
    exit 2;
fi

if [ -z "$MIN_REPLICAS" ]; then
    echo "Must provide MIN_REPLICAS in environment" 1>&2
    exit 2;
fi

if [ -z "$MAX_REPLICAS" ]; then
    echo "Must provide MAX_REPLICAS in environment" 1>&2
    exit 2;
fi

if [[ $METRIC =~ ^jetstream_.* ]]; then
    METRICS_SOURCE_TYPE="Pods"
    METRICS_SOURCE="pods"
elif [ $METRIC == memory_used ] && [ "$ADAPTER" == custom-metrics-stackdriver-adapter ]; then
    METRICS_SOURCE_TYPE="External"
    METRICS_SOURCE="external"
    METRIC="kubernetes.io|node|accelerator|${METRIC}"
elif [ $METRIC == memory_used_percentage ] && [ "$ADAPTER" == prometheus-adapter ]; then
    METRICS_SOURCE_TYPE="External"
    METRICS_SOURCE="external"
else
    echo "Must provide valid METRIC for ${ADAPTER} in environment" 1>&2
    exit 2;
fi

if [ -z "$AVERAGE_VALUE" ]; then
    echo "Must provide AVERAGE_VALUE in environment" 1>&2
    exit 2;
fi

echo "apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: jetstream-hpa-$(uuidgen)
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: maxengine-server
  minReplicas: ${MIN_REPLICAS}
  maxReplicas: ${MAX_REPLICAS}
  metrics:
  - type: ${METRICS_SOURCE_TYPE}
    ${METRICS_SOURCE}:
      metric:
        name: ${METRIC}
      target:
        type: AverageValue
        averageValue: ${AVERAGE_VALUE}
" | kubectl apply -f -
 ```
