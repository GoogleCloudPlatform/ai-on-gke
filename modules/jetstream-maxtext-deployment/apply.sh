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