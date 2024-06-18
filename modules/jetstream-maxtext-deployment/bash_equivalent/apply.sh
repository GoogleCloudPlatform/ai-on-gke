if [ -z "$BUCKET_NAME" ]; then
    echo "Must provide BUCKET_NAME in environment" 1>&2
    exit 2;
fi

jq \
    --arg LOAD_PARAMETERS_ARG "load_parameters=gs://$BUCKET_NAME/final/unscanned/gemma_7b-it/0/checkpoints/0/items" \
    '.spec.template.spec.containers[0].args += [$LOAD_PARAMETERS_ARG]' \
deployment.json | kubectl apply -f -