# Package and Deploy from Hugging Face to Artifact Registry and GKE

This repository contains a Google Cloud Build configuration for building and pushing Docker images of Hugging Face models to Google Artifact Registry.

## Overview

This project allows you to download a Hugging Face model and package it as a Docker image. The Docker image can then be pushed to Google Artifact Registry for deployment or distribution. Build time can be significant for large models, it is recommended to not exceed models above 10 billion parameters. For reference 8b model roughly takes 35 minutes to build and push with this cloudbuild config.

## Prerequisites

- A Google Cloud project with billing enabled.
- Google Cloud SDK installed and authenticated.
- Access to Google Cloud Build and Artifact Registry.
- A Hugging Face account with an access token.

## SetupCreate a Secret for Hugging Face Token

1. **Clone the Repository**

   ```bash
   git clone https://github.com/your-username/your-repo-name.git
   cd your-repo-name
2. **Create a Secret for Hugging Face Token**
   ```bash 
   echo "your_hugging_face_token" | gcloud secrets create huggingface-token --data-file=-

## Configuration

### Substitutions

The following substitutions are defined in the `cloudbuild.yaml` file, they can be changed by passing `--substitutions SUBSTITUTION_NAME=SUBSTITUTION_VALUE` to `gcloud builds submit`:

- **`_MODEL_NAME`**: The name of the Hugging Face model to download (default: `huggingfaceh4/zephyr-7b-beta`).
- **`_REGISTRY`**: The URL for the Docker registry (default: `us-docker.pkg.dev`).
- **`_REPO`**: The name of the Artifact Registry repository (default: `cloud-blog-oci-models`).
- **`_IMAGE_NAME`**: The name of the Docker image to be created (default: `zephyr-7b-beta`).
- **`_CLOUD_SECRET_NAME`**: The name of the secret storing the Hugging Face token (default: `huggingface-token`).

### Options

The following options are configured in the `cloudbuild.yaml` file:

- **`diskSizeGb`**: The size of the disk for the build, specified in gigabytes (default: `100`). can be changed by passing `--disk-size=DISK_SIZE` to `gcloud builds submit`
- **`machineType`**: The machine type can be set by passing `--machine-type=` in `gcloud builds submit`

## Usage

To trigger the Cloud Build and create the Docker image, run the following command:

```bash
gcloud builds submit --config cloudbuild.yaml --substitutions _MODEL_NAME="your_model_name",_IMAGE_NAME="LOCATION-docker.pkg.dev/[YOUR_PROJECT_ID]/[REPOSITORY_NAME]/[IMAGE_NAME]"
```

## Usage

### Inside an Inference Deployment Dockerfile

#### Example

```Dockerfile
# Start from the PyTorch base image with CUDA and cuDNN support
FROM pytorch/pytorch:2.1.2-cuda12.1-cudnn8-devel

# Set the working directory
WORKDIR /srv

# Install vllm (version 0.3.3)
RUN pip install vllm==0.3.3 --no-cache-dir

# Import the model from the 'model-as-image'
FROM model-as-image as model

# Copy the model files from 'model-as-image' into the inference container
COPY --from=model /model/ /srv/models/$MODEL_DIR/

# Define the entrypoint to run the VLLM OpenAI API server
ENTRYPOINT ["python", "-m", "vllm.entrypoints.openai.api_server", \
            "--host", "0.0.0.0", "--port", "80", \
            "--model", "/srv/models/$MODEL_DIR", \
            "--dtype=half"]
```
### Mount the image as to your inference deployment
You can mount the image to a shared volume in your inference deployment via a sidecar 

### example

```yaml
initContainers:
  - name: model
    image: model-as-image
    restartPolicy: Always
    args:
    - "sh"
    - "-c"
    - "ln -s /model /mnt/model && sleep infinity"
    volumeMounts:
    - mountPath: /mnt/model
      name: model-image-mount
      readOnly: False
volumes:
  - name: dshm
    emptyDir:
      medium: Memory
  - name: llama3-model
    emptyDir: {}
```
Mount the same volume to your inference container and consume it there. 
**Pulling images can be optimized in Google Kubernetes Engine with [image streaming](https://cloud.google.com/kubernetes-engine/docs/how-to/image-streaming) and [secondary boot disk](https://cloud.google.com/kubernetes-engine/docs/how-to/data-container-image-preloading)**. These method can be used for packaging and mass distributing small/medium size models and low rank adapters of foundational models. 
