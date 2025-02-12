# Training ESM2 LLM on GKE using BioNeMo Framework 2.0

This repo walks through setting up a Google Cloud GKE environment to train ESM2 (Evolutionary Scale Modeling) using NVIDIA BioNeMo Framework 2.0

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
export CLUSTER_NAME="gke-bionemo-dev"
export NODE_POOL_NAME="gpu-bionemo-np"

export ZONE="your-zone"  # e.g., us-east5-b
export MACHINE_TYPE="your-machine-type" # e.g., a2-ultragpu-1g
export ACCELERATOR_TYPE="your-accelerator-type" # e.g., nvidia-a100-80gb
export ACCELERATOR_COUNT="1" # Or higher, as needed
export NODE_POOL_NODES=1 # Or higher, as needed
```

Adjust the zone, machine type, accelerator type, count, and number of nodes as per your requirements. Refer to Google Cloud documentation for available options. Consider smaller machine types for development to manage costs.

3. Create a GKE Cluster

```bash
gcloud container clusters create "${CLUSTER_NAME}" \
--num-nodes="1" \
--location="${ZONE}" \
--machine-type="e2-standard-16" \
--addons=GcpFilestoreCsiDriver
```

4. Create GPU Node Pool:

```bash
gcloud container node-pools create "${NODE_POOL_NAME}" \
--cluster="${CLUSTER_NAME}" \
--location="${ZONE}" \
--node-locations="${ZONE}" \
--num-nodes="${NODE_POOL_NODES}" \
--machine-type="${MACHINE_TYPE}" \
--accelerator="type=${ACCELERATOR_TYPE},count=${ACCELERATOR_COUNT},gpu-driver-version=LATEST" \
--placement-type="COMPACT" \
--disk-type="pd-ssd" \
--disk-size="300GB"
```

This creates a node pool specifically for GPU workloads.

5. Get Cluster Credentials:

```bash
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
--location="${ZONE}"
```

6. Create and mount Google cloud Filestore for storage

```bash
alias k=kubectl

k apply -f create-mount-fs.yaml
```

Wait for the filestore to be in READY status. It takes a few minutes.

7. Kickoff the training job

```bash
k apply -f esm2-training.yaml
```

8. Port Forwarding (for TensorBoard):

```bash
POD_BIONEMO_TRAINING=$(k get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep '^bionemo-training')

k port-forward pod/$POD_BIONEMO_TRAINING :6006

```

9. View Tensorboard logs

On your local machine: Browse to <http://localhost:[local> port forward from above step]/#timeseries and see the loss curves as show below

[<img src="images/tensorboard-results.png" width="750"/>](HighLevelArch)

## Cleanup

To delete the cluster and all associated resources:

```bash
k delete -f esm2-training.yaml
k delete -f create-mount-fs.yaml

gcloud container clusters delete "${CLUSTER_NAME}" --location="${ZONE}" --quiet

```


## commands

```
export PROJECT_ID=${DEVSHELL_PROJECT_ID}
export REGION=us-central1
export ZONE=us-central1-a
export CLUSTER_NAME=bionemo-demo
export NODE_POOL_MACHINE_TYPE=a2-highgpu-2g
export CLUSTER_MACHINE_TYPE=e2-standard-4
export GPU_TYPE=nvidia-tesla-a100
export GPU_COUNT=2
export WORKLOAD_POOL=${DEVSHELL_PROJECT_ID}.svc.id.goog

gcloud services enable file.googleapis.com --project ${PROJECT_ID}

gcloud container clusters create ${CLUSTER_NAME} \
    --project=${PROJECT_ID} \
    --location=${ZONE} \
    --workload-pool=${WORKLOAD_POOL} \
    --release-channel=rapid \
    --addons=GcpFilestoreCsiDriver \
    --machine-type=${CLUSTER_MACHINE_TYPE} \
    --num-nodes=1

gcloud container node-pools create gpupool \
    --accelerator type=${GPU_TYPE},count=${GPU_COUNT},gpu-driver-version=latest \
    --project=${PROJECT_ID} \
    --location=${ZONE} \
    --cluster=${CLUSTER_NAME} \
    --machine-type=${NODE_POOL_MACHINE_TYPE} \
    --num-nodes=1
    --disk-type="pd-ssd" \
    --disk-size="300GB"

kubectl port-forward -n bionemo-training svc/tensorboard-service 8080:6006

kubectl apply -k pretraining/ or kubectl apply -k fine-tuning/
```