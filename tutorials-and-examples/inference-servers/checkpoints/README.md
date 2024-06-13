# Checkpoint conversion

The `checkpoint_entrypoint.sh` script overviews how to convert your inference checkpoint for various model servers.

Build the checkpoint conversion Dockerfile
```
docker build -t inference-checkpoint .
docker tag inference-checkpoint gcr.io/${PROJECT_ID}/inference-checkpoint:latest
docker push gcr.io/${PROJECT_ID}/inference-checkpoint:latest
```

Now you can use it in a [Kubernetes job](../jetstream/maxtext/single-host-inference/checkpoint-job.yaml) and pass the following arguments

Jetstream + MaxText
```
- -i=INFERENCE_SERVER
- -b=BUCKET_NAME
- -m=MODEL_PATH
- -v=VERSION (Optional)
```

Jetstream + Pytorch/XLA
```
- -i=INFERENCE_SERVER
- -m=MODEL_PATH
- -q=QUANTIZE (Optional)
- -v=VERSION
- -1=EXTRA_PARAM_1
- -2=EXTRA_PARAM_2
```