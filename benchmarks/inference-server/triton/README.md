# AI on GKE: Benchmark TensorRT LLM on Triton Server

This guide provides instructions for deploying and benchmarking a TensorRT Large Language Model (LLM) on Triton Inference Server within a Google Kubernetes Engine (GKE) environment. The process involves building a Docker image with the TensorRT LLM engine and deploying it to a GKE cluster. 

## Prerequisites

- Docker
- Google Cloud SDK
- Kubernetes CLI (kubectl)
- Hugging Face account for model access
- NVIDIA GPU drivers and CUDA toolkit (to build the TensorRTLLM Engine)

## Step 1: Build the TensorRT LLM Engine and Docker Image

1. **Build the TensorRT LLM Engine:** Follow the instructions provided in the [TensorRT LLM backend repository](https://github.com/triton-inference-server/tensorrtllm_backend/blob/main/README.md) to build the TensorRT LLM Engine.

2. **Setup the Docker image:**
   
   ***Method 1: Add the Model repository and the relevant scripts to the image***
   Inside the `tritonllm_backend` directory, create a Dockerfile with the following content ensuring the Triton Server is ready with the necessary models and scripts.

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

   The Shell script `/opt/scripts/start_triton_servers.sh` is like below: 

   ```start_triton_servers.sh
   #!/bin/bash


    # Use the environment variable to log in to Hugging Face CLI
    huggingface-cli login --token $HUGGINGFACE_TOKEN




    # Launch the servers (modify this depending on the number of GPU used and the exact path to the model repo)
    mpirun --allow-run-as-root -n 1 /opt/tritonserver/bin/tritonserver \
    --model-repository=/all_models/inflight_batcher_llm \
    --disable-auto-complete-config \
    --backend-config=python,shm-region-prefix-name=prefix0_ : \
    -n 1 /opt/tritonserver/bin/tritonserver \
    --model-repository=/all_models/inflight_batcher_llm \
    --disable-auto-complete-config \
    --backend-config=python,shm-region-prefix-name=prefix1_ :```
   ```
   *Build and Push the Docker Image:*

   Build the Docker image and push it to your container registry:

   ```
   docker build -t your_registry/tritonserver_llm:latest .
   docker push your_registry/tritonserver_llm:latest

   ```
   Replace `your_registry` with your actual Docker registry path.

   ***Method 2: Upload Model repository and the relevant scripts to gcs***

   In this method we can directly upload the model engine and scripts to gcs and use the base image provided by Nvidia: 
   ```
   gsutil cp -r gs://your_model_repo/scripts/ ./
   gsutil cp -r gs://your_model_repo/all_models/ ./
   ```
   Replace `your_model_repo` with your actual gcs repo path.




## Step 2: Create and Configure `terraform.tfvars`

1. **Initialize Terraform Variables:**

   Create a `terraform.tfvars` file by copying the provided example:

   ```bash
   cp sample-terraform.tfvars terraform.tfvars
   ```

2. Define `template_path` variable  in `terraform.tfvars`
   If usinng method 1 In Step 1 above:
   ```bash
   template_path = "path_to_manifest_template/triton-tensorrtllm-inference.tftpl" 
   image_path = "path_to_your_registry/tritonserver_llm:latest"
   gpu_count = X
   ```
   If using method 2 In Step 1 above:
   
   ```bash
   template_path = "path_to_manifest_template/triton-tensorrtllm-inference-gs.tftpl"
   image_path = "nvcr.io/nvidia/tritonserver:23.10-trtllm-python-py3"
   gpu_count = X
   ```
   and also update the `triton-tensorrtllm-inference-gs.tftpl` with the path to the gcs repo under InitContainer and the command to launch the container under Container section.

3. **Configure Your Deployment:**

   Edit the `terraform.tfvars` file to include your specific configuration details. At a minimum, you must specify the `credentials_config` for accessing Google Cloud resources and the `image_path` to your Docker image in the registry. Update the gpu_count to make it consistent with the TensorRTLLM Engine configuration when it was [built](https://github.com/NVIDIA/TensorRT-LLM/tree/0f041b7b57d118037f943fd6107db846ed147b91/examples/llama).

Example `terraform.tfvars` content:

   ```bash
   credentials_config = {
     kubeconfig = "path/to/your/gcloud/credentials.json"
   }
   ```

#### [optional] set-up credentials config with kubeconfig 

If you created your cluster with steps from `../../infra/` or with fleet management enabled, the existing `credentials_config` must use the fleet host credentials like this:
```bash
credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/global/gkeMemberships/$CLUSTER_NAME"
}
```


If you created your own cluster without fleet management enabled, you can use your cluster's kubeconfig in the `credentials_config`. You must isolate your cluster's kubeconfig from other clusters in the default kube.config file. To do this, run the following command:

```bash
KUBECONFIG=~/.kube/${CLUSTER_NAME}-kube.config gcloud container clusters get-credentials $CLUSTER_NAME --location $CLUSTER_LOCATION
```

Then update your `terraform.tfvars` `credentials_config` to the following:

```bash
credentials_config = {
  kubeconfig = {
    path = "~/.kube/${CLUSTER_NAME}-kube.config"
  }
}
```

#### [optional] set up secret token in Secret Manager

A model may require a security token to access it. For example, Llama2 from HuggingFace is a gated model that requires a [user access token](https://huggingface.co/docs/hub/en/security-tokens). If the model you want to run does not require this, skip this step.

If you followed steps from `../../infra/stage-2`, Secret Manager and the user access token should already be set up. Alternatively you can create a Kubernetes Secret to store your Hugging Face CLI token. You can do this from the command line with kubectl:
```bash
kubectl create secret generic huggingface-secret --from-literal=token='************'
```

This command creates a new Secret named huggingface-secret, which has a key token containing your Hugging Face CLI token.

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
| `image_path`         | Image Path stored in Artifact Registry                                                        | String  |                                           | No       |
| `model_id`           | Model used for inference.                                                                     | String  | `"meta-llama/Llama-2-7b-chat-hf"`         | No       |
| `gpu_count`          | Parallelism based on number of gpus.                                                          | Number  | `1`                                       | No       |
| `ksa`                | Kubernetes Service Account used for workload.                                                 | String  | `"default"`                               | No       |
| `huggingface-secret` | Name of the kubectl huggingface secret token                                                  | String  | `"huggingface-secret"`                    | No       |
| `templates_path`     | Path where manifest templates will be read from.     | String  |                                    | No      |

## Notes

- The `credentials_config` variable is an object that may contain either a `fleet_host` or `kubeconfig` (not both), each with optional fields. This ensures either one method of authentication is configured.
- The `templates_path` variable can be set to `null` to use default manifests, indicating its nullable nature and the use of a default value.
- Default values are provided for several variables (`namespace`, `model_id`, `gpu_count`, `ksa`, and `huggingface-secret`), ensuring ease of use and defaults that make sense for most scenarios.
- The `nullable = false` for most variables indicates they must explicitly be provided or have a default value, ensuring crucial configuration is not omitted.
