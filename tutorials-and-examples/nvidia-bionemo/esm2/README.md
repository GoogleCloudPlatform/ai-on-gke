# Training and Fine-tuning ESM2 LLM on GKE using BioNeMo Framework 2.0

This repo walks through setting up a Google Cloud GKE environment to train ESM2 (Evolutionary Scale Modeling) using NVIDIA BioNeMo Framework 2.0

## Table of Contents

- [Prerequisites](#prerequisites)
- [Setup](#setup)
  - [Training](#training)
  - [Fine-tuning](#fine-tuning)
- [Cleanup](#cleanup)

## Prerequisites

- **GCloud SDK:** Ensure you have the Google Cloud SDK installed and configured.
- **Project:**  A Google Cloud project with billing enabled.
- **Permissions:**  Sufficient permissions to create GKE clusters and other related resources.
- **kubectl:** kubectl command-line tool installed and configured.
- **NVIDIA GPUs:**  NVIDIA A100 80GB(3) GPU preferred in the same region / zone.

Clone the repo before proceeding further:

```bash

git clone https://github.com/GoogleCloudPlatform/ai-on-gke
cd ai-on-gke/tutorials-and-examples/nvidia-bionemo/esm2

```

## Setup

1. Set Project:

```bash
gcloud config set project "your-project-id"
```

Replace "your-project-id" with your actual project ID.

2. Set Environment Variables:

```bash
export CLUSTER_NAME="gke-bionemo-esm2"
export ZONE="your-zone"  # e.g., us-east5-b

export NP_CPU_MACHTYPE="e2-standard-2" # e.g., e2-standard-2

export NP_NAME="gpu-bionemo-np"
export NP_GPU_MACHTYPE="a2-ultragpu-1g"    # e.g., a2-ultragpu-1g
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
 --machine-type="${NP_CPU_MACHTYPE}" \
 --addons=GcpFilestoreCsiDriver

```

4. Create GPU Node Pool:

```bash
gcloud container node-pools create "${NP_NAME}" \
--cluster="${CLUSTER_NAME}" \
--location="${ZONE}" \
--node-locations="${ZONE}" \
--num-nodes="${NODE_POOL_NODES}" \
--machine-type="${NP_GPU_MACHTYPE}" \
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

7. Wait for the Filestore instance to be ready.  You can check its status using the following command:

```bash
k get persistentvolumeclaim fileserver -o yaml | grep phase:

```

The output should show `phase: Bound` when the Filestore instance is ready.

## Training

8. Kickoff the training job. The training job will automatically create ./results and store the checkpoints under esm2 in the Filestore mounted earlier under `/mnt/data`.

```bash
k apply -f esm2-training.yaml
```

9. Port Forwarding (for TensorBoard):

> [!NOTE]
> It is assumed that the local port 8000 is available. If the post is unavailable, do update below to an available port.

```bash
POD_BIONEMO_TRAINING=$(k get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep '^bionemo-training')

k port-forward pod/$POD_BIONEMO_TRAINING 8000:6006

```

10. View Tensorboard logs

On your local machine: Browse to <<http://localhost:8000/#timeseries> and see the loss curves as show below

[<img src="images/tensorboard-results.png" width="750"/>](HighLevelArch)

## Fine-tuning

11. Start the fine-tuning job. The results will be written to a .pt file

```bash
k apply -f esm2-finetunine.yaml
k get pods
k exec -it <pod-name> -- bash

#Copy contents of finetuning.py into the pod
touch finetuning.py
vi finetuning.py
#paste contents into the file
python3 finetuning.py
```

## Cleanup

To delete the cluster and all associated resources:

```bash
k delete -f esm2-finetuning.yaml
k delete -f esm2-training.yaml
k delete -f create-mount-fs.yaml

gcloud container clusters delete "${CLUSTER_NAME}" --location="${ZONE}" --quiet

```
