## Bash equivalent of this module

Assure the following are set before running:
   - BUCKET_NAME: Bucket name to be used in your checkpoint path
   - METRICS_PORT: Port to emit custom metrics on
   - (optional) MAXENGINE_SERVER_IMAGE: Maxengine server container image
   - (optional) JETSTREAM_HTTP_SERVER_IMAGE: Jetstream HTTP server container image

```
if [ -z "$MAXENGINE_SERVER_IMAGE" ]; then
    MAXENGINE_SERVER_IMAGE="us-docker.pkg.dev\/cloud-tpu-images\/inference\/maxengine-server:v0.2.2"
fi

if [ -z "$JETSTREAM_HTTP_SERVER_IMAGE" ]; then
    JETSTREAM_HTTP_SERVER_IMAGE="us-docker.pkg.dev\/cloud-tpu-images\/inferenc\/jetstream-http:v0.2.2"
fi

if [ -z "$BUCKET_NAME" ]; then
    echo "Must provide BUCKET_NAME in environment" 1>&2
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
| sed "s/\${maxengine_server_image}/$MAXENGINE_SERVER_IMAGE/g" \
| sed "s/\${jetstream_http_server_image}/$JETSTREAM_HTTP_SERVER_IMAGE/g" \
| sed "s/\${load_parameters_path_arg}/load_parameters=gs:\/\/$BUCKET_NAME\/final\/unscanned\/gemma_7b-it\/0\/checkpoints\/0\/items/g" >> "$JETSTREAM_MANIFEST"

cat $JETSTREAM_MANIFEST | kubectl apply -f -
```

### Metrics Adapter

#### Custom Metrics Stackdriver Adapter

Follow the [Custom-metrics-stackdriver-adapter README](LINK HERE)

#### Prometheus Adapter

Follow the [Prometheus-adapter README](AWAITING OTHER MERGE), a few notes:

This module requires the cluster name to be passed in manually via the CLUSTER_NAME variable to filter incoming metrics. This is a consequence of differing cluster name schemas between GKE and standard k8s clusters. Instructions for each are as follows for if the cluster name isnt already known. For GKE clusters, Remove any characters prior to and including the last underscore with `kubectl config current-context | awk -F'_' ' { print $NF }'` to get the cluster name. For other clusters, The cluster name is simply: `kubectl config current-context`.

Instructions to set the PROMETHEUS_HELM_VALUES_FILE env var as follows:

```
PROMETHEUS_HELM_VALUES_FILE=$(mktemp)
sed "s/\${cluster_name}/$CLUSTER_NAME/g" ../templates/values.yaml.tftpl >> "$PROMETHEUS_HELM_VALUES_FILE"
```


