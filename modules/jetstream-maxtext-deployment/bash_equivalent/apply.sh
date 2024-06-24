if [ -z "$BUCKET_NAME" ]; then
    echo "Must provide BUCKET_NAME in environment" 1>&2
    exit 2;
fi

JETSTREAM_MANIFEST="$(cat deployment.json)"
PODMONITORING_MANIFEST="$(cat podmonitoring.json)"

if [ "$METRICS_PORT" != "" ]; then
    PODMONITORING_MANIFEST="$(echo "$PODMONITORING_MANIFEST" \
    | jq \
        --arg METRICS_PORT "$METRICS_PORT" \
        '.spec.endpoints[0].port = $METRICS_PORT')"
    JETSTREAM_MANIFEST="$(echo "$JETSTREAM_MANIFEST" \
    |  jq \
        --arg METRICS_PORT_ARG "prometheus_port=$METRICS_PORT" \
        '.spec.template.spec.containers[0].args += [$METRICS_PORT_ARG]')"
fi

JETSTREAM_MANIFEST="$(echo "$JETSTREAM_MANIFEST" \
    |  jq \
        --arg LOAD_PARAMETERS_ARG "load_parameters=gs://$BUCKET_NAME/final/unscanned/gemma_7b-it/0/checkpoints/0/items" \
        '.spec.template.spec.containers[0].args += [$LOAD_PARAMETERS_ARG]')"

echo $JETSTREAM_MANIFEST | kubectl apply -f -
echo $PODMONITORING_MANIFEST | kubectl apply -f -