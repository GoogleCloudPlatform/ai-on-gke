# AI on GKE: Benchmark TensorRT LLM on Triton Server

>[!WARNING]
>This guide and associated code are **deprecated** and no longer maintained.
>
>Please refer to the [GKE AI Labs website](https://gke-ai-labs.dev) for the latest tutorials and quick start solutions.

This guide outlines the steps for deploying and benchmarking a TensorRT Large Language Model (LLM) on the Triton Inference Server within Google Kubernetes Engine (GKE). It includes the process of building a Docker container equipped with the TensorRT LLM engine and deploying this container to a GKE cluster.

## Prerequisites

Ensure you have the following prerequisites installed and set up:
- Docker for containerization
- Google Cloud SDK for interacting with Google Cloud services
- Kubernetes CLI (kubectl) for managing Kubernetes clusters
- A Hugging Face account to access models
- NVIDIA GPU drivers and CUDA toolkit for building the TensorRT LLM Engine
## Step 1: Build the TensorRT LLM Engine and Docker Image

1. **Build the TensorRT LLM Engine:** Follow the instructions provided in the [TensorRT LLM backend repository](https://github.com/triton-inference-server/tensorrtllm_backend/blob/main/README.md) to build the TensorRT LLM Engine.

2. **Upload the Model to Google Cloud Storage (GCS)**

   Transfer your model engine to GCS using:
   ```
   gsutil cp -r your_model_folder gs://your_model_repo/all_models/ 
   ```
   *Ensure to replace your_model_repo with your actual GCS repository path.**
   
   **Alternate method: Add the Model repository and the relevant scripts to the image**

   Construct a new image from Nvidia's base image and integrate the model repository and necessary scripts directly into it, bypassing the need for GCS during runtime. In the `tritonllm_backend` directory, create a Dockerfile with the following content:
   ```Dockerfile
   FROM nvcr.io/nvidia/tritonserver:23.10-trtllm-python-py3

   # Copy the necessary files into the container
   COPY all_models /all_models
   COPY scripts /opt/scripts

   # Install Python dependencies
   RUN pip install sentencepiece protobuf

   RUN chmod +x /opt/scripts/start_triton_servers.sh

   CMD ["/opt/scripts/start_triton_servers.sh"]
   ```

    For the initialization script located at `/opt/scripts/start_triton_servers.sh`, follow the structure below:

   ```start_triton_servers.sh
   #!/bin/bash


    # Use the environment variable to log in to Hugging Face CLI
    huggingface-cli login --token $HUGGINGFACE_TOKEN




    # Launch the servers (modify this depending on the number of GPU used and the exact path to the model repo)
    mpirun --allow-run-as-root  -n 1 /opt/tritonserver/bin/tritonserver \
    --model-repository=/all_models/inflight_batcher_llm \
    --disable-auto-complete-config \
    --backend-config=python,shm-region-prefix-name=prefix0_ : \
    -n 1 /opt/tritonserver/bin/tritonserver \
    --model-repository=/all_models/inflight_batcher_llm \
    --disable-auto-complete-config \
    --backend-config=python,shm-region-prefix-name=prefix1_ :
   ```
    *Build and Push the Docker Image:*

    Build the Docker image and push it to your container registry:

   ```
   docker build -t your_registry/tritonserver_llm:latest .
   docker push your_registry/tritonserver_llm:latest

   ```
    Substitute `your_registry` with your Docker registry's path.




## Step 2: Create and Configure `terraform.tfvars`

1. **Initialize Terraform Variables:**

   Start by creating a `terraform.tfvars` file from the provided template:

   ```bash
   cp sample-terraform.tfvars terraform.tfvars
   ```

2. **Specify Essential Variables**
   
   At a minimum, configure the `gcs_model_path` in `terraform.tfvars` to point to your Google Cloud Storage (GCS) repository. You may also need to adjust `image_path`, `gpu_count`, and `server_launch_command_string` according to your specific requirements.
   ```bash   
   gcs_model_path = gs://path_to_model_repo/all_models
   ```

   If `gcs_model_path` is not defined, it is inferred that you are utilizing the method of direct image integration. In this scenario, ensure to update `image_path` along with any pertinent variables accordingly:

  ```bash
   image_path = "path_to_your_registry/tritonserver_llm:latest"
   ```

3. **Configure Your Deployment:**

  Edit `terraform.tfvars` to tailor your deployment's configuration, particularly the `credentials_config`. Depending on your cluster's setup, this might involve specifying fleet host credentials or isolating your cluster's kubeconfig:

  ***For Fleet Management Enabled Clusters:***
```bash
credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/global/gkeMemberships/$CLUSTER_NAME"
}
``` 
  ***For Clusters without Fleet Management:***
Separate your cluster's kubeconfig:
```bash
KUBECONFIG=~/.kube/${CLUSTER_NAME}-kube.config gcloud container clusters get-credentials $CLUSTER_NAME --location $CLUSTER_LOCATION
```

And then update your `terraform.tfvars`  accordingly:

```bash
credentials_config = {
  kubeconfig = {
    path = "~/.kube/${CLUSTER_NAME}-kube.config"
  }
}
```

#### [optional] Setting Up Secret Tokens

A model may require a security token to access it. For example, Llama2 from HuggingFace is a gated model that requires a [user access token](https://huggingface.co/docs/hub/en/security-tokens). If the model you want to run does not require this, skip this step.

If you followed steps from `../../infra/stage-2`, Secret Manager and the user access token should already be set up. Alternatively you can create a Kubernetes Secret to store your Hugging Face CLI token. You can do this from the command line with kubectl:
```bash
kubectl create secret generic huggingface-secret --from-literal=token='************'
```

Executing this command generates a new Secret named huggingface-secret, which incorporates a key named token that stores your Hugging Face CLI token. It is important to note that for any production or shared environments, directly storing user access tokens as literals is not advisable.


## Step 3: login to gcloud

Run the following gcloud command for authorization:

```bash
gcloud auth application-default login
```

## Step 4: terraform initialize, plan and apply

Run the following terraform commands:

```bash
# initialize terraform
terraform init

# verify changes
terraform plan

# apply changes
terraform apply
```

# Variables

| Variable             | Description                                                                                   | Type    | Default                                   | Nullable |
|----------------------|-----------------------------------------------------------------------------------------------|---------|-------------------------------------------|----------|
| `credentials_config` | Configure how Terraform authenticates to the cluster.                                         | Object  |                                           | No       |
| `namespace`          | Namespace used for Nvidia DCGM resources.                                                     | String  | `"default"`                               | No       |
| `image_path`         | Image Path stored in Artifact Registry                                                        | String  |    "nvcr.io/nvidia/tritonserver:23.10-trtllm-python-py3"                                       | No       |
| `model_id`           | Model used for inference.                                                                     | String  | `"meta-llama/Llama-2-7b-chat-hf"`         | No       |
| `gpu_count`          | Parallelism based on number of gpus.                                                          | Number  | `1`                                       | No       |
| `ksa`                | Kubernetes Service Account used for workload.                                                 | String  | `"default"`                               | No       |
| `huggingface_secret` | Name of the kubectl huggingface secret token                                                  | String  | `"huggingface-secret"`                    | Yes       |
| `gcs_model_path`     | Path where model engine in gcs will be read from.     | String  |    null                                | Yes      |
| `server_launch_command_string`     | Command to launc the Triton Inference Server     | String  |   "pip install sentencepiece protobuf && huggingface-cli login --token $HUGGINGFACE_TOKEN && /opt/tritonserver/bin/tritonserver --model-repository=/all_models/inflight_batcher_llm --disable-auto-complete-config --backend-config=python,shm-region-prefix-name=prefix0_"                                 | No      |




## Notes

- The `credentials_config` variable is an object that may contain either a `fleet_host` or `kubeconfig` (not both), each with optional fields. This ensures either one method of authentication is configured.
- The `templates_path` variable can be set to `null` to use default manifests, indicating its nullable nature and the use of a default value.
- Default values are provided for several variables (`namespace`, `model_id`, `gpu_count`, `ksa`, and `huggingface-secret`), ensuring ease of use and defaults that make sense for most scenarios.
- The `nullable = false` for most variables indicates they must explicitly be provided or have a default value, ensuring crucial configuration is not omitted.
