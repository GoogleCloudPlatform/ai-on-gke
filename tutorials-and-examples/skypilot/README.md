# GKE cross region capacity chasing with SkyPilot
Due to the limited availability of accelerator resources, customers face significant challenges in securing sufficient capacity to run their AI/ML workloads. They often require:

* Preferences for VM families and accelerators, with the ability to automatically fail over to alternative configurations if their preferred resources are unavailable.
* Automatic capacity acquisition across regions to address scenarios where a specific region lacks sufficient resources.

In this tutorial, we will demonstrate how to leverage the open-source software [SkyPilot](https://skypilot.readthedocs.io/en/latest/docs/index.html) to help GKE customers efficiently obtain accelerators across regions, ensuring workload continuity and optimized resource utilization.

SkyPilot is a framework for running AI and batch workloads on any infra, offering unified execution, high cost savings, and high GPU availability. By combining SkyPilot with GKE's solutions (such as [Kueue + Dynamic Workload Scheduler](https://cloud.google.com/kubernetes-engine/docs/how-to/provisioningrequest), [Custom compute class](https://cloud.google.com/kubernetes-engine/docs/concepts/about-custom-compute-classes), [GCS FUSE](https://cloud.google.com/storage/docs/cloud-storage-fuse/overview)), users can effectively address capacity challenges while optimizing costs.

## The overview. 
In this tutorial, our persona is an ML scientist planning to run a batch workload for hyperparameter tuning. This workload involves two experiments, with each experiment requiring 4 GPUs to execute. 

We have two GKE clusters in different regions: one in us-central1 with 4*A100 and another in us-west1 with 4*L4.

By the end of this tutorial, our goal is to have one experiment running in the us-central cluster and the other in the us-west cluster, demonstrating efficient resource distribution across regions.

SkyPilot supports GKE's cluster autoscaling for dynamic resource management. However, to keep this tutorial straightforward, we will demonstrate the use of a static node pool instead.

## Before you begin
1. Ensure you have a gcp project with billing enabled and [enabled the GKE API](https://cloud.google.com/kubernetes-engine/docs/how-to/enable-gkee). 

2. Ensure you have the following tools installed on your workstation
* [gcloud CLI](https://cloud.google.com/sdk/docs/install)
* [gcloud kubectl](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_kubectl)

## Set up your GKE Cluster
Create two clusters, you can create  the clusters in parrallel to reduce time.
1. Set the default environment variables:
```bash
export PROJECT_ID=$(gcloud config get project)
```
2. Create a GKE cluster in us-central1-c with 4*A100
```bash
gcloud container clusters create demo-us-central1 \
    --location=us-central1-c \
    --project=$PROJECT_ID 
```
```bash
gcloud container node-pools create gpu-node-pool \
  --accelerator type=nvidia-tesla-a100,count=4 \
  --machine-type a2-highgpu-4g \
  --region us-central1-c \
  --cluster=demo-us-central1 \
  --num-nodes=1
```

```bash
gcloud container clusters get-credentials demo-us-central1 \
--region us-central1-c \
--project ${PROJECT_ID}
```

3. Create a GKE cluster in us-west1-c with 4*L4
```bash
gcloud container clusters create demo-us-west1 \
    --location=us-west1-c \
    --project=$PROJECT_ID 
```
```bash
gcloud container node-pools create gpu-node-pool \
  --accelerator type=nvidia-l4,count=4 \
  --machine-type g2-standard-48 \
  --region us-west1-c \
  --cluster=demo-us-west1 \
  --num-nodes=1
```

```bash
gcloud container clusters get-credentials demo-us-west1 \
--region us-west1-c \
--project ${PROJECT_ID}
```

## Install SkyPilot
1. Create a virtual environment.
```bash
cd ~
git clone https://github.com/GoogleCloudPlatform/ai-on-gke.git
cd ai-on-gke/tutorials-and-examples/skypilot
python3 -m venv ~/ai-on-gke/tutorials-and-examples/skypilot
source bin/activate 
```

2. Install SkyPilot
```bash
pip install -U "skypilot[kubernetes,gcp]"
```
```bash
sky check

sky show-gpus
```

3. Find the context names
```bash
kubectl config get-contexts

# Find the context name, for example: 
gke_${PROJECT_NAME}_us-central1-c_demo-us-central1
gke_${PROJECT_NAME}_us-west1-c_demo-us-west1
```

4. Copy the following yaml to ~/.sky/config.yaml with context name replaced.
SkyPilot will evaludate the contexts by the order specified until it finds a cluster that provides enough capacity to deploy the workload.
```yaml
allowed_clouds:
  - gcp
  - kubernetes
kubernetes:
  # Use the context's name
  allowed_contexts:
    - gke_${PROJECT_NAME}_us-central1-c_demo-us-central1
    - gke_${PROJECT_NAME}_us-west1-c_demo-us-west1
  provision_timeout: 30
```

## Launch the jobs
Under `~/ai-on-gke/tutorials-and-examples/skypilot`, you’ll find a file named `train.yaml`, which uses SkyPilot's syntax to define a job. The job will ask for 4* A100 first. If no capacity is found, it failovers to L4. 
```yaml
resources:
  cloud: kubernetes
  # list has orders
  accelerators: [ A100:4, L4:4 ]
```

The `launch.py` a Python program that initiates a hyperparameter tuning process with two candidates for the learning rate (LR) parameter. In production environments, such experiments are typically tracked using open-source frameworks like MLFlow.

Start the trainig:
```bash
python launch.py
```
SkyPilot will first select the demo-us-central1 cluster, which has 4 A100 GPUs available. For the second job, it will launch in the demo-us-west1 cluster using L4 GPUs, as no additional clusters with 4 A100 GPUs were available.

You also can check SkyPilot's status using: 
```bash
sky status
```

You can SSH into the pod in GKE using the cluster's name. Once inside, you'll find the local source code synced to the pod under `~/sky_workdir`. This setup makes it convenient for developers to debug and iterate on their AI/ML code efficiently.

```bash
ssh train-cluster1
```

## Clean up
Delete the GKE clusters.
```bash
gcloud container clusters delete demo-us-central1 \
    --location=us-central1-c \
    --project=$PROJECT_ID
```

```bash
gcloud container clusters delete demo-us-west1 \
    --location=us-west1-c \
    --project=$PROJECT_ID
```