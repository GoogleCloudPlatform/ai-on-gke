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

**Note**: Google Cloud shell is recommended to run this sample.

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
export ZONE=us-central1-b
export CLUSTER_NAME=bionemo-demo
export NODE_POOL_MACHINE_TYPE=a2-highgpu-2g
export CLUSTER_MACHINE_TYPE=e2-standard-4
export GPU_TYPE=nvidia-tesla-a100
export GPU_COUNT=2
```

Adjust the zone, machine type, accelerator type, count, and number of nodes as per your requirements. Refer to Google Cloud documentation for available options. Consider smaller machine types for development to manage costs.

3. Enable the Filestore API and create a GKE Cluster

```bash
gcloud services enable file.googleapis.com --project ${PROJECT_ID}
```

```bash
gcloud container clusters create ${CLUSTER_NAME} \
    --project=${PROJECT_ID} \
    --location=${ZONE} \
    --addons=GcpFilestoreCsiDriver \
    --machine-type=${CLUSTER_MACHINE_TYPE} \
    --num-nodes=1 \
    --workload-pool=${PROJECT_ID}.svc.id.goog
```

4. Create GPU Node Pool:

```bash
gcloud container node-pools create gpupool \
    --project=${PROJECT_ID} \
    --location=${ZONE} \
    --cluster=${CLUSTER_NAME} \
    --machine-type=${NODE_POOL_MACHINE_TYPE} \
    --num-nodes=1 \
    --accelerator type=${GPU_TYPE},count=${GPU_COUNT},gpu-driver-version=latest
```

This creates a node pool specifically for GPU workloads.

5. Get Cluster Credentials:

```bash
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
--location="${ZONE}"
```

6. Create an Artifact Registry to store container images

```bash
gcloud artifacts repositories create ${PUBLIC_REPOSITORY} --repository-format=docker --location=${REGION}
```

7. Create service account to allow GKE to pull images

```bash
gcloud iam service-accounts create esm2-inference-gsa \
    --project=$PROJECT_ID
```

8. Create namespace, training job, tensorboard microservice, and mount Google cloud Filestore for storage

```bash
kubectl create namespace bionemo-training

kubectl create serviceaccount esm2-inference-sa -n bionemo-training
```

9. Create identity binding

```bash
gcloud iam service-accounts add-iam-policy-binding esm2-inference-gsa@${PROJECT_ID}.iam.gserviceaccount.com --role="roles/iam.workloadIdentityUser" --member="serviceAccount:${PROJECT_ID}.svc.id.goog[bionemo-training/esm2-inference-sa]"
```

```bash
kubectl annotate serviceaccount esm2-inference-sa -n bionemo-training iam.gke.io/gcp-service-account=esm2-inference-gsa@$PROJECT_ID.iam.gserviceaccount.com
```
Note: this requires workload identity to be configured at the cluster level.

10. Launch fine-tuning job

make sure you are in this directory

```bash
cd tutorials-and-examples/nvidia-bionemo/
```

then apply the kustomize file

```bash
kubectl apply -k fine-tuning/job
```

11. build and push inference server docker image 

```bash
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${PUBLIC_REPOSITORY}/esm2-inference:latest fine-tuning/inference/.
```

```bash
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${PUBLIC_REPOSITORY}/esm2-inference:latest
```

12. Launch inference deployment

ensure job status is `Complete` by running:

```bash
kubectl get job esm2-finetuning -n bionemo-training
```

Ensure environment variables `REGION`, `PROJECT_ID`, and `PUBLIC_REPOSITORY` are fully set.

```bash
envsubst < fine-tuning/inference/kustomization.yaml | sponge fine-tuning/inference/kustomization.yaml
```

```bash
kubectl apply -k fine-tuning/inference
```

13. Port Forwarding (for inference):

List deployment PODs 

```bash
kubectl get pods -l app=esm2-inference -n bionemo-training
```

Once the inference POD is under `Running` status, run:

```bash
kubectl port-forward -n bionemo-training svc/esm2-inference 8080:80
```

in a separate shell window, run:

```bash
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"sequence": "MKTVRQERLKSIVRILERSKEPVSGAQLAEELSVSRQVIVQDIAYLRSLGYNIVATPRGYVLAGG"}'
```

## Cleanup

To delete the cluster and all associated resources:

```bash
kubectl delete namespace bionemo-training --cascade=background
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