#!/bin/bash
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Please reset these values to your GCP project ID and compute zone, Please change these variables\\
PROJECT_ID="your-project-id"
COMPUTE_ZONE="your-compute-zone"
CLUSTER_NAME="mistral-gke-cluster"

# Authenticate with Google Cloud
gcloud auth login
gcloud config set project $PROJECT_ID
gcloud config set compute/zone $COMPUTE_ZONE

# Create GKE cluster
gcloud container clusters create mixtral8x7-cluster-gke \
  --region=${REGION} \
  --node-locations=${REGION} \
  --project=${PROJECT_ID} \
  --machine-type=n2d-standard-8 \
  --no-enable-master-authorized-networks \
  --addons=HorizontalPodAutoscaling \
  --addons=HttpLoadBalancing \
  --addons=GcePersistentDiskCsiDriver \
  --addons=GcsFuseCsiDriver \
  --num-nodes=4 \
  --min-nodes=3 \
  --max-nodes=6 \
  --enable-ip-alias \
  --enable-image-streaming \
  --enable-shielded-nodes \
  --shielded-secure-boot \
  --shielded-integrity-monitoring \
  --workload-pool=${PROJECT_ID}.svc.id.goog \
  --logging=SYSTEM,WORKLOAD \
  --monitoring=SYSTEM \
  --enable-autoupgrade \
  --enable-autorepair \
  --network="projects/${PROJECT_ID}/global/networks/default" \
  --subnetwork="projects/${PROJECT_ID}/regions/${REGION}/subnetworks/default" \
  --tags=web,sftp \
  --labels=env=production,team=mixtral8x7 \
  --release-channel=regular
```


# Configure single GPU setup node pool with 1*Nvidia-L4 GPU
gcloud container node-pools create mixtral-moe-gpu-pool \
  --cluster=mixtral8x7-cluster-gke  \
  --project=gke-aishared-dev \
  --machine-type=g2-standard-48 \
  --ephemeral-storage-local-ssd=count=4 \
  --accelerator=type=nvidia-l4,count=4 \
  --node-locations=us-west4-a \
  --enable-image-streaming \
  --num-nodes=1 \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=2 \
  --node-labels=accelerator=nvidia-gpu \
  --workload-metadata=GKE_METADATA
    # Please Adjust max-nodes to node scaling as desired by deployment


# Install NVIDIA GPU driver, if needed seperately 
# kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/daemonset.yaml