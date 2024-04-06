# NVIDIA NIM on GKE with NVIDIA L4s

## Prerequisites
* docker
* golang
* yq

## Set up your GKE Cluster

Choose your region and set your project and machine variables:
```bash
export REGION=us-central1
export ZONE=${REGION?}-b
export PROJECT_ID=$(gcloud config get project)
export MACH=g2-standard-24
export GPU_TYPE=nvidia-l4
export GPU_COUNT=2
```

Set model variables
```bash
export NGC_MODEL_NAME=llama-2-7b
export TRT_MODEL_NAME=trt_llm_0.0.1_trtllm
export TRITON_MODEL_NAME=trt_llm
export NGC_MODEL_VERSION=LLAMA-2-7B-4K-FP16
```

Alternative configuration for A100s #TODO: Remove this
```bash
export REGION=us-central1
export MACH=a2-highgpu-1g
export GPU_TYPE=nvidia-tesla-a100
export GPU_COUNT=1
```

Create a GKE cluster:
```bash
gcloud container clusters create nim-demo --location ${REGION?} \
  --workload-pool ${PROJECT_ID?}.svc.id.goog \
  --enable-image-streaming \
  --enable-ip-alias \
  --node-locations=$REGION-a \
  --workload-pool=${PROJECT_ID?}.svc.id.goog \
  --addons=GcpFilestoreCsiDriver  \
  --machine-type n2d-standard-4 \
  --num-nodes 1 --min-nodes 1 --max-nodes 5 \
  --ephemeral-storage-local-ssd=count=2
```

## Set Up Access to NVIDIA NIM
Access to NVIDIA NIM is available through the NVIDIA Early Access (EA) Program.  <INSERT Text From NVIDIA>

Get your NGC_API_KEY from NGC - TODO: Add detailed instructions and link to NVIDIA docs
```bash
export NGC_CLI_API_KEY="<YOUR_API_KEY>"
```

Ensure you have access to the repository by listing the models
```bash
ngc registry model list "ohlfw0olaadg/ea-participants/*"
```

Add the NVIDIA NIM helm repo
```bash
helm repo add nemo-ms "https://helm.ngc.nvidia.com/ohlfw0olaadg/ea-participants" --username=\$oauthtoken --password=$NGC_CLI_API_KEY
```

Create a Kuberntes namespace and switch context to that namespace
```bash
kubectl create namespace nim
kubectl config set-context --current --namespace nim

```
Create Kubernetes secrets to enable access to NGC resources from within your cluster
```bash
kubectl -n nim create secret docker-registry registry-secret --docker-server=nvcr.io --docker-username='$oauthtoken' --docker-password=$NGC_CLI_API_KEY
kubectl -n nim create secret generic ngc-api --from-literal=NGC_CLI_API_KEY=$NGC_CLI_API_KEY
```

## Preload container image and mount to new NVIDIA L4 GPU node pool
For more information on mounting a secondary boot disk on GKE to improve performance, see [Use secondary boot disks to preload data or container images](https://cloud.google.com/kubernetes-engine/docs/how-to/data-container-image-preloading)

Authorize docker to pull images from NGC repo
```bash
docker login -u $oauthtoken -p ${NGC_CLI_API_KEY?}
```

Pull image locally
```bash
docker pull nvcr.io/ohlfw0olaadg/ea-participants/nemollm-inference-ms:23.12.a
```

Enable Artifact Registry and create a private repo to store the image
```bash
gcloud artifacts repositories create nim-demo-repo \
    --repository-format=docker \
    --location=${REGION?}

gcloud auth configure-docker ${REGION?}-docker.pkg.dev
```

Create a service account with permissions to pull container images from this repo
```bash
export SERVICE_ACCOUNT="nim-demo@${PROJECT_ID?}.iam.gserviceaccount.com"

gcloud iam service-accounts create nim-demo \
    --description="Service account for nim-demo"

gcloud artifacts repositories add-iam-policy-binding nim-demo-repo \
    --member=serviceAccount:nim-demo@${PROJECT_ID?}.iam.gserviceaccount.com \
    --role=roles/artifactregistry.reader \
    --location ${REGION?}
```

Retag image and push to your private repo
```bash
docker tag nvcr.io/ohlfw0olaadg/ea-participants/nemollm-inference-ms:23.12.a ${REGION?}-docker.pkg.dev/${PROJECT_ID?}/nim-demo-repo/nemollm-inference-ms:23.12.a
docker push ${REGION?}-docker.pkg.dev/${PROJECT_ID?}/nim-demo-repo/nemollm-inference-ms:23.12.a
```

Create a cloud storage bucket to store the disk image and logs
```bash
export BUCKET_NAME=nim-images

gcloud storage buckets create gs://${BUCKET_NAME?} --location=${REGION?}
```

Assign the required GCS permissions to the Google Service Account:
```bash
gcloud storage buckets add-iam-policy-binding gs://${BUCKET_NAME?} \
  --member="serviceAccount:${SERVICE_ACCOUNT?}" --role=roles/storage.admin
```

Assign the required compute image permissions to the Google Service Account:
```bash
gcloud storage buckets add-iam-policy-binding gs://${BUCKET_NAME?} \
  --member="serviceAccount:${SERVICE_ACCOUNT?}" --role=roles/storage.admin
```

Allow the Kubernetes Service Account `nim-demo` in the `nim` namespace to use the Google Service Account:
```bash
gcloud iam service-accounts add-iam-policy-binding ${SERVICE_ACCOUNT?} \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${PROJECT_ID}.svc.id.goog[nim/nim-demo]"
```

Create a new Kubernetes Service Account:
```bash
kubectl create serviceaccount -n nim nim-demo
kubectl annotate serviceaccount -n nim nim-demo iam.gke.io/gcp-service-account=nim-demo@${PROJECT_ID}.iam.gserviceaccount.com
```

Create a disk image from the container image.  Note that the disk image builder 
```bash
export DISK_IMAGE_NAME=nemollm-inference-ms
export CONTAINER_IMAGE=${REGION?}-docker.pkg.dev/${PROJECT_ID?}/nim-demo-repo/nemollm-inference-ms:23.12.a

WORKING_DIR=${PWD?}
cd ../../tools/gke-disk-image-builder
go run ./cli \
    --project-name=${PROJECT_ID?} \
    --image-name=${DISK_IMAGE_NAME?} \
    --zone=${REGION?}-a \
    --gcs-path=gs://${BUCKET_NAME} \
    --disk-size-gb=50 \
    --container-image=${CONTAINER_IMAGE?} \
    --service-account=${SERVICE_ACCOUNT?} \
    --image-pull-auth=ServiceAccountToken
cd ${WORKING_DIR}
```

```bash
gcloud compute images add-iam-policy-binding nemollm-inference-ms \
  --member="serviceAccount:${SERVICE_ACCOUNT?}" --role=roles/compute.imageUser
```

Create a nodepool where each VM has 2 x L4 GPU:
```bash
gcloud container node-pools create ${MACH?}-node-pool --cluster nim-demo \
   --accelerator type=${GPU_TYPE?},count=${GPU_COUNT?},gpu-driver-version=latest \
  --machine-type ${MACH?} \
  --ephemeral-storage-local-ssd=count=${GPU_COUNT?} \
  --enable-autoscaling --enable-image-streaming \
  --num-nodes=1 --min-nodes=1 --max-nodes=3 \
  --node-locations ${REGION?}-b \
  --region ${REGION?}
  # --spot #TODO: Enable spot to increase obtainability
```


## Deploy the NIM with the generated engine using a Helm chart

```bash
gcloud filestore instances create nim-nfs --zone=${ZONE?} --tier=BASIC_HDD --file-share=name="ms03",capacity=1TB --network=name="default"
gcloud filestore instances describe nim-nfs --zone=${ZONE?}
export FS_IP=$(gcloud filestore instances describe nim-nfs --zone=${ZONE?} --format json | jq '.networks[] | select(.network == "default").ipAddresses[0]' - | sed 's/["'\'']//g')
```

```bash
envsubst < k8s/model-pv.yaml | kubectl apply -f -
```

Deploy the helm chart.  NOTE: We're making a small patch on the chart based [this known issue](#issue-chart-incompatible-version)
```bash
helm pull nemo-ms/nemollm-inference --version=0.1.2 --untar
yq -i '.kubeVersion = ">=v1.23.0-1"' ./nemollm-inference/Chart.yaml
envsubst < values.${GPU_TYPE?}.yaml | helm --namespace nim install inference-ms ./nemollm-inference --version=0.1.2 -f -
```

## Test the NIM
Expose the service
```bash
kubectl port-forward services/inference-ms-nemollm-inference 8005
```

Send a test prompt
```bash
curl -X 'POST' \
  'http://localhost:8005/v1/chat/completions' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "messages": [
    {
      "content": "You are a polite and respectful chatbot helping people plan a vacation.",
      "role": "system"
    },
    {
      "content": "What should I do for a 4 day vacation in Spain?",
      "role": "user"
    }
  ],
  "model": "llama-2-7b-chat",
  "max_tokens": 160,
  "top_p": 1,
  "n": 1,
  "stream": false,
  "stop": "\n",
  "frequency_penalty": 0.0
}' | jq '.choices[0].message.content' -
```

## Appendix

### Known Issues

#### nemollm-inference helm chart incompatible version {#issue-chart-incompatible-version}
```bash
$ helm --namespace nim install my-inference-ms nemo-ms/nemollm-inference --version=0.1.2 -f values.yaml

Error: INSTALLATION FAILED: chart requires kubeVersion: >=v1.23.0 which is incompatible with Kubernetes v1.27.8-gke.1067004
```

### Under Construction

#### Convert the Llama 2 Chat Model to be compatible with L4 GPUs
There are prebuilt engines available from NVIDIA.  To view currently available models, run the `ngc registry model list` command.  In this tutorial, we'll show how to build our own engine using the `Llama 2 13B Chat` model on NVIDIA L4 GPUs. 
 For more information on generating models, see [NVIDIA Model Repo Generator](https://developer.nvidia.com/docs/nemo-microservices/inference/model-repo-generator.html#llama-2-chat-models)

Download the Llama2-13b-chat model
```bash
ngc registry model download-version "ohlfw0olaadg/ea-participants/LLAMA-2-13B-CHAT-4K-FP16.23.12.rc3"
```
TODO: Fix the following output error
```json
{
    "error": "Error: Target 'ohlfw0olaadg/ea-participants/LLAMA-2-13B-CHAT-4K-FP16.23.12.rc3' could not be found."
}  
```

We're going to use the following config, available in this tutorial as `model_config.yaml` to build our engine.
```yaml
model_repo_path: "/model-store/"
model_type: "LLAMA"
backend: "trt_llm"
customization_cache_capacity: 10000
logging_level: "INFO"
enable_chat: true
preprocessor:
  chat_cfg:
    roles:
      system:
        prefix: "[INST] <<SYS>>\n"
        suffix: "\n<</SYS>>\n\n"
      user:
        prefix: ""
        suffix: " [/INST] "
      assistant:
        prefix: ""
        suffix: " </s><s>[INST] "
    stop_words: ["</s>"]
    rstrip_turn: true
    turn_suffix: "\n"
pipeline:
  model_name: "ensemble"
  num_instances: 128
trt_llm:
  use: true
  model_name: "trt_llm"
  model_type: "llama"
  ckpt_type: "hf"
  model_path: "/model-downloads/Llama-2-13b-chat-hf"
  data_type: "float16"
  num_gpus: 1
  tensor_para_size: 1
  pipeline_para_size: 1
  max_batch_size: 128
  max_input_len: 4096
  max_output_len: 4096
  max_num_tokens: 50000
```

Let's create a configmap to make this config available to the `Model Repo Generator` job
```bash
kubectl create configmap model-config --from-file=model_config.yaml
```