# Fine-Tuning ESM2 LLM on GKE using BioNeMo Framework 2.0

This sample walks through setting up a Google Cloud GKE environment to fine-tune ESM2 (Evolutionary Scale Modeling) using NVIDIA BioNeMo Framework 2.0

## Table of Contents

- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Cleanup](#cleanup)

## Prerequisites

- **GCloud SDK:** Ensure you have the Google Cloud SDK installed and configured.
- **Project:**  A Google Cloud project with billing enabled.
- **Permissions:**  Sufficient permissions to create GKE clusters and other related resources.
- **kubectl:** kubectl command-line tool installed and configured.
- **NVIDIA GPUs:** One of the below GPUs should work
  - [NVIDIA L4 GPU (2)](https://cloud.google.com/compute/docs/gpus#l4-gpus)
  - [NVIDIA A100 40GB (1) GPU or higher](https://cloud.google.com/compute/docs/gpus#a100-gpus)
  - [NVIDIA H100 80GB (1) GPU or higher](https://cloud.google.com/compute/docs/gpus#a3-series)

**Note**: Google Cloud shell is recommended to run this sample.

You can skip this step, if done previously.

  ```bash
  git clone https://github.com/GoogleCloudPlatform/ai-on-gke
  cd ai-on-gke/tutorials-and-examples/nvidia-bionemo
  ```

## Setup

1. Set Project:

```bash
gcloud config set project "your-project-id"
```

Replace "your-project-id" with your actual project ID.

2. Set Environment Variables:

```bash
export PROJECT_ID="your-project-id"
export PUBLIC_REPOSITORY=$PROJECT_ID
export REGION=us-central1
export ZONE=us-central1-a
export CLUSTER_NAME=bionemo-demo
export NODE_POOL_MACHINE_TYPE=a2-highgpu-1g # e.g., g2-standard-24 (L4) or a2-ultragpu-1g (A100 80GB)
export CLUSTER_MACHINE_TYPE=e2-standard-2 
export GPU_TYPE=nvidia-tesla-a100 # e.g., nvidia-l4 (L4) OR nvidia-a100-80gb (A100 80GB)
export GPU_COUNT=1 # e.g., 2 (L4) OR 1 (A100 80GB)
export NETWORK_NAME="default"
```

Adjust the zone, machine type, accelerator type, count, and number of nodes as per your requirements. Refer to [Google Cloud documentation](https://cloud.google.com/compute/docs/gpus) for available options. Consider smaller machine types for development to manage costs.

> NOTE:
> Skip steps 3-5 if you are reusing the same GKE cluster from pretraining.

3. Enable the Filestore API

```bash
gcloud services enable file.googleapis.com
```

4. Create GKE Cluster

```bash
gcloud container clusters create ${CLUSTER_NAME} \
    --location=${ZONE} \
    --network=${NETWORK_NAME} \
    --addons=GcpFilestoreCsiDriver \
    --machine-type=${CLUSTER_MACHINE_TYPE} \
    --num-nodes=1 \
    --workload-pool=${PROJECT_ID}.svc.id.goog
```

5. Create GPU Node Pool:

```bash
gcloud container node-pools create gpupool \
    --location=${ZONE} \
    --cluster=${CLUSTER_NAME} \
    --machine-type=${NODE_POOL_MACHINE_TYPE} \
    --num-nodes=1 \
    --accelerator type=${GPU_TYPE},count=${GPU_COUNT},gpu-driver-version=latest
```

This creates a node pool specifically for GPU workloads.

6. Get Cluster Credentials:

```bash
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --location="${ZONE}"
```

7. Create an Artifact Registry to store container images

```bash
gcloud artifacts repositories create ${PUBLIC_REPOSITORY} \
  --repository-format=docker --location=${REGION}
```

8. Create service account to allow GKE to pull images

```bash
gcloud iam service-accounts create esm2-inference-gsa
```

9. Create namespace, training job, tensorboard microservice, and mount Google cloud Filestore for storage

```bash
alias k=kubectl

k create namespace bionemo-training

k create serviceaccount esm2-inference-sa -n bionemo-training
```

10. Create identity binding

This is needed to allow the GKE POD to pull the custom image from the artifact registry we just created in a previous step

```bash
gcloud iam service-accounts add-iam-policy-binding esm2-inference-gsa@${PROJECT_ID}.iam.gserviceaccount.com --role="roles/iam.workloadIdentityUser" --member="serviceAccount:${PROJECT_ID}.svc.id.goog[bionemo-training/esm2-inference-sa]"
```

```bash
k annotate serviceaccount esm2-inference-sa -n bionemo-training iam.gke.io/gcp-service-account=esm2-inference-gsa@$PROJECT_ID.iam.gserviceaccount.com
```

> Note:
> This requires workload identity to be configured at the cluster level.

11. Launch fine-tuning job by applying the kustomize file

```bash
k apply -k fine-tuning/job
```

Check job status by running:

```bash
k get job esm2-finetuning -n bionemo-training
```

You will need if the job has succeded once its status is `Complete`.

12. build and push inference server docker image

```bash
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${PUBLIC_REPOSITORY}/esm2-inference:latest fine-tuning/inference/.
```

Authenticate to artifact registry:

```bash
gcloud auth configure-docker ${REGION}-docker.pkg.dev
```

```bash
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${PUBLIC_REPOSITORY}/esm2-inference:latest
```

13. Launch inference deployment

ensure job status is `Complete` by running:

```bash
k get job esm2-finetuning -n bionemo-training
```

Ensure environment variables `REGION`, `PROJECT_ID`, and `PUBLIC_REPOSITORY` are fully set.

```bash
envsubst < fine-tuning/inference/kustomization.yaml | sponge fine-tuning/inference/kustomization.yaml
```

```bash
k apply -k fine-tuning/inference
```

14. Port Forwarding (for inference):

List deployment PODs

```bash
k get pods -l app=esm2-inference -n bionemo-training
```

Wait for a few minutes for the inference POD to be in `Running` status, run:

```bash
k port-forward -n bionemo-training svc/esm2-inference 8080:80
```

in a separate shell window, run:

```bash
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"sequence": "MKTVRQERLKSIVRILERSKEPVSGAQLAEELSVSRQVIVQDIAYLRSLGYNIVATPRGYVLAGG"}'
```

See [here](https://docs.nvidia.com/bionemo-framework/latest/user-guide/examples/bionemo-esm2/inference/) documentation reference.

## Cleanup

To delete the cluster and all associated resources:

```bash
k delete namespace bionemo-training --cascade=background
```

```bash
gcloud container clusters delete "${CLUSTER_NAME}" --location="${ZONE}" --quiet
```

```bash
gcloud artifacts repositories delete ${PUBLIC_REPOSITORY} \
    --location=${REGION} \
    --quiet
```

```bash
gcloud iam service-accounts delete esm2-inference-gsa@${PROJECT_ID}.iam.gserviceaccount.com \
    --quiet
```

```bash
docker rmi ${REGION}-docker.pkg.dev/${PROJECT_ID}/${PUBLIC_REPOSITORY}/esm2-inference:latest
```
