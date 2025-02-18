# Training ESM2 LLM on GKE using BioNeMo Framework 2.0

This samples walks through setting up a Google Cloud GKE environment to train ESM2 (Evolutionary Scale Modeling) using NVIDIA BioNeMo Framework 2.0

## Table of Contents

- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Cleanup](#cleanup)

## Prerequisites

- **GCloud SDK:** Ensure you have the Google Cloud SDK installed and configured.
- **Project:**  A Google Cloud project with billing enabled.
- **Permissions:**  Sufficient permissions to create GKE clusters and other related resources.

## Setup

1. Set Project:

```bash
gcloud config set project "your-project-id"
```

Replace "your-project-id" with your actual project ID.

2. Set Environment Variables:

```bash
export PROJECT_ID="your-project-id"
export REGION=us-central1
export ZONE=us-central1-a
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
    --num-nodes=1
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

6. Create namespace, training job, tensorboard microservice, and mount Google cloud Filestore for storage

```bash
alias k=kubectl

k apply -k pretraining/
```

7. Port Forwarding (for TensorBoard):

List PODs and ensure tensorboard POD is under `READY` status

```bash
k get pods -n bionemo-training
```

```bash
k port-forward -n bionemo-training svc/tensorboard-service 8080:6006
```

9. View Tensorboard logs

On your local machine: Browse to <http://localhost:8080> port forward from above step timeseries and see the loss curves as show below

[<img src="./images/tensorboard-results.png" width="750"/>](HighLevelArch)

## Cleanup

To delete the cluster and all associated resources:

```bash
k delete -k pretraining/

gcloud container clusters delete "${CLUSTER_NAME}" --location="${ZONE}" --quiet
```