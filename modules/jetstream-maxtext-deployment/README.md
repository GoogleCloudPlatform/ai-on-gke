## Bash equivalent of this module

Assure the following are set before running
   - BUCKET_NAME: Bucket name to be used in your checkpoint path
   - METRICS_PORT: Port to emit custom metrics on

```
if [ -z "$BUCKET_NAME" ]; then
    echo "Must provide BUCKET_NAME in environment" 1>&2
    exit 2;
fi

JETSTREAM_MANIFEST="$(cat ./templates/deployment.json)"
PODMONITORING_MANIFEST="$(cat ./templates/podmonitoring.json)"

if [ "$METRICS_PORT" != "" ]; then
    PODMONITORING_MANIFEST="$(echo "$PODMONITORING_MANIFEST" \
    | jq \
        --arg METRICS_PORT "$METRICS_PORT" \
        '.spec.endpoints[0].port = $METRICS_PORT')"
    JETSTREAM_MANIFEST="$(echo "$JETSTREAM_MANIFEST" \
    |  jq \
        --arg METRICS_PORT_ARG "prometheus_port=$METRICS_PORT" \
        '.spec.template.spec.containers[0].args += [$METRICS_PORT_ARG]')"
    echo $PODMONITORING_MANIFEST | kubectl apply -f -
fi

JETSTREAM_MANIFEST="$(echo "$JETSTREAM_MANIFEST" \
    |  jq \
        --arg LOAD_PARAMETERS_ARG "load_parameters=gs://$BUCKET_NAME/final/unscanned/gemma_7b-it/0/checkpoints/0/items" \
        '.spec.template.spec.containers[0].args += [$LOAD_PARAMETERS_ARG]')"

echo $JETSTREAM_MANIFEST | kubectl apply -f -
```

### Metrics Adapter

#### Custom Metrics Stackdriver Adapter

Follow the [Custom-metrics-stackdriver-adapter README](LINK HERE)

#### Prometheus Adapter

Follow the [Prometheus-adapter README](AWAITING OTHER MERGE), a few notes:

This module requires the cluster name to be passed in manually via the CLUSTER_NAME variable to filter incoming metrics. This is a consequence of differing cluster name schemas between GKE and standard k8s clusters. Instructions for each are as follows for if the cluster name isnt already known. For GKE clusters, Remove any charachters prior to and including the last underscore with `kubectl config current-context | awk -F'_' ' { print $NF }'` to get the cluster name. For other clusters, The cluster name is simply: `kubectl config current-context`.

Instructions to set the PROMETHEUS_HELM_VALUES_FILE env var as follows:

```
PROMETHEUS_HELM_VALUES_FILE=$(mktemp)
sed "s/\${cluster_name}/$CLUSTER_NAME/g" ../templates/values.yaml.tftpl >> "$PROMETHEUS_HELM_VALUES_FILE"
```


