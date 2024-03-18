#!/bin/bash

# Please reset these values to your GCP project ID and compute zone, Please change these variables\\
PROJECT_ID="your-project-id"
COMPUTE_ZONE="your-compute-zone"
CLUSTER_NAME="mistral-gke-cluster"

# Authenticate with Google Cloud
gcloud auth login
gcloud config set project $PROJECT_ID
gcloud config set compute/zone $COMPUTE_ZONE

# Create GKE cluster
gcloud container clusters create mistral-cluster-gke  \
    --location=${REGION} \
    --node-locations=${REGION} \
    --project= ${PROJECT_ID} \
    --machine-type=n1-standard-4 \
    --no-enable-master-authorized-networks \
    --addons=GcsFuseCsiDriver \
    --num-nodes=3 \
    --min-nodes=1 \
    --max-nodes=5 \
    --enable-ip-alias \
    --enable-image-streaming \
    --enable-shielded-nodes \
    --shielded-secure-boot \
    --shielded-integrity-monitoring \
    --workload-pool=${WORKLOAD_POOL}.svc.id.goog
```


# Configure single GPU setup node pool with 1*Nvidia-L4 GPU
gcloud container node-pools create mistral-gpu-pool \
    --cluster=mistral-cluster \
    --region=${REGION} \
    --project=${PROJECT_ID}} \
    --machine-type=g2-standard-12 \
    --accelerator=type=nvidia-l4,count=1,gpu-driver-version=latest \
    --node-locations=${ZONE} \
    --num-nodes=1 \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=2 \
    --node-labels=accelerator=nvidia-gpu
    # Please Adjust max-nodes to node scaling as desired by deployment


# Install NVIDIA GPU driver, if needed seperately 
# kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/daemonset.yaml