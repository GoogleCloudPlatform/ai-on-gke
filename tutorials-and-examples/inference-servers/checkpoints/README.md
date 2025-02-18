# Checkpoint conversion

The `checkpoint_entrypoint.sh` script overviews how to convert your inference checkpoint for various model servers.

Build the checkpoint conversion Dockerfile
```
docker build -t inference-checkpoint .
docker tag inference-checkpoint ${LOCATION}-docker.pkg.dev/${PROJECT_ID}/jetstream/inference-checkpoint:latest
docker push ${LOCATION}-docker.pkg.dev/${PROJECT_ID}/jetstream/inference-checkpoint:latest
```

Now you can use it in a [Kubernetes job](../jetstream/maxtext/single-host-inference/checkpoint-job.yaml) and pass the following arguments

## Jetstream + MaxText
```
-b, --bucket_name: [string] The GSBucket name to store checkpoints, without gs://.
-s, --inference_server: [string] The name of the inference server that serves your model. (Optional) (default=jetstream-maxtext)
-m, --model_path: [string] The model path.
-n, --model_name: [string] The model name.
-h, --huggingface: [bool] The model is from Hugging Face. (Optional) (default=False)
-t, --quantize_type: [string] The type of quantization. (Optional)
-q, --quantize_weights: [bool] The checkpoint is to be quantized. (Optional) (default=False)
-i, --input_directory: [string] The input directory, likely a GSBucket path.
-o, --output_directory: [string] The output directory, likely a GSBucket path.
-u, --meta_url: [string] The url from Meta. (Optional)
-v, --version: [string] The version of repository. (Optional) (default=main)
```

## Jetstream + Pytorch/XLA
```
- -s, --inference_server: [string] The name of the inference server that serves your model.
- -m, --model_path: [string] The model path.
- -n, --model_name: [string] The model name, Model name, ex. llama-2, llama-3, gemma.
- -q, --quantize_weights: [bool] The checkpoint is to be quantized. (Optional) (default=False)
- -t, --quantize_type: [string] The type of quantization. Availabe quantize type: {"int8", "int4"} x {"per_channel", "blockwise"}. (Optional) (default=int8_per_channel)
- -v, --version: [string] The version of repository to override, ex. jetstream-v0.2.2, jetstream-v0.2.3. (Optional) (default=jetstream-v0.2.3)
- -i, --input_directory: [string] The input directory, likely a GSBucket path. (Optional)
- -o, --output_directory: [string] The output directory, likely a GSBucket path.
- -h, --huggingface: [bool] The model is from Hugging Face. (Optional) (default=False)
```