if [ -z "$BUCKET_NAME" ]; then
    echo "Must provide BUCKET_NAME in environment" 1>&2
    exit 2;
fi

if [ "$IMPLEMENTATION" == "JAX" ]; then
    cat deployment.json |
    jq \
        --arg BUCKET_ARG "-b=$BUCKET_NAME" \
        '.spec.template.spec.containers[0].args = ["-m=google/gemma/maxtext/7b-it/2", $BUCKET_ARG]' | 
    kubectl apply -f -

elif [ "$IMPLEMENTATION" == "PYTORCH" ]; then
    cat deployment.json |
    jq \
        '.spec.template.metadata.annotations = {
            "gke-gcsfuse/volumes" : "true"
        }' | 
    jq \
        --arg BUCKET_NAME "$BUCKET_NAME" \
        '.spec.template.spec.volumes += [{
            "name" : "gcs-fuse-checkpoint",
            "csi" : {
                "driver": "gcsfuse.csi.storage.gke.io",
                "readOnly": true,
                "volumeAttributes": {
                    "bucketName" : $BUCKET_NAME,
                    "mountOptions": "implicit-dirs"
                }
            }
        }]' |
    jq \
        --arg ONE_FLAG_ARG "-1=gs://$BUCKET_NAME/pytorch/llama2-7b/base/" \
        --arg TWO_FLAG_ARG "-2=gs://$BUCKET_NAME/pytorch/llama2-7b/final/bf16/" \
        '.spec.template.spec.containers[0].args = ["-i=jetstream-pytorch","-m=/models", $ONE_FLAG_ARG, $TWO_FLAG_ARG]' |
    jq \
        '.spec.template.spec.containers[0].volumeMounts += [{
            "name": "gcs-fuse-checkpoint",
            "mountPath": "/models",
            "readOnly": true
        }]' | 
    kubectl apply -f -
else
    echo "Must provide valid IMPLEMENTATION in environment, valid values are JAX or PYTORCH" 1>&2
    exit 2;
fi

