# Checkpoint conversion

The `checkpoint_entrypoint.sh` script overviews how to convert your inference checkpoint for various model servers.

Build the checkpoint conversion Dockerfile
```
docker build -t inference-checkpoint .
docker tag inference-checkpoint gcr.io/${PROJECT_ID}/inference-checkpoint:latest
docker push gcr.io/${PROJECT_ID}/inference-checkpoint:latest
```

Now you can use it in a [Kubernetes job](../jetstream/maxtext/single-host-inference/checkpoint-job.yaml) and pass the following arguments

## Jetstream + MaxText
```
- -s=INFERENCE_SERVER
- -b=BUCKET_NAME
- -m=MODEL_PATH
- -v=VERSION (Optional)
```

## Jetstream + Pytorch/XLA
```
- -s=INFERENCE_SERVER
- -m=MODEL_PATH
- -n=MODEL_NAME
- -q=QUANTIZE_WEIGHTS (Optional) (default=False)
- -t=QUANTIZE_TYPE (Optional) (default=int8_per_channel)
- -v=VERSION (Optional) (default=jetstream-v0.2.3)
- -i=INPUT_DIRECTORY (Optional)
- -o=OUTPUT_DIRECTORY
- -h=HUGGINGFACE (Optional) (default=False)
```

## Argument descriptions:
```
b) BUCKET_NAME: (str) GSBucket, without gs://
s) INFERENCE_SERVER: (str) Inference server, ex. jetstream-maxtext, jetstream-pytorch
m) MODEL_PATH: (str) Model path, varies depending on inference server and location of base checkpoint
n) MODEL_NAME: (str) Model name, ex. llama-2, llama-3, gemma
h) HUGGINGFACE: (bool) Checkpoint is from HuggingFace.
q) QUANTIZE_WEIGHTS: (str) Whether to quantize weights
t) QUANTIZE_TYPE: (str) Quantization type, QUANTIZE_WEIGHTS must be set to true. Availabe quantize type: {"int8", "int4"} x {"per_channel", "blockwise"},
v) VERSION: (str) Version of inference server to override, ex. jetstream-v0.2.2, jetstream-v0.2.3
i) INPUT_DIRECTORY: (str) Input checkpoint directory, likely a GSBucket path
o) OUTPUT_DIRECTORY: (str) Output checkpoint directory, likely a GSBucket path
```