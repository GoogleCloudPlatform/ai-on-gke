# AI on GKE Assets
 test 
This repository contains assets related to AI/ML workloads on
[Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine/docs/integrations/ai-infra).

## Overview

Run optimized AI/ML workloads with Google Kubernetes Engine (GKE) platform orchestration capabilities. A robust AI/ML platform considers the following layers:

- Infrastructure orchestration that support GPUs and TPUs for training and serving workloads at scale
- Flexible integration with distributed computing and data processing frameworks
- Support for multiple teams on the same infrastructure to maximize utilization of resources

## Infrastructure

The AI-on-GKE application modules assumes you already have a functional GKE cluster. If not, follow the instructions under [infrastructure/README.md](./infrastructure/README.md) to install a Standard or Autopilot GKE cluster.

```bash
.
├── LICENSE
├── README.md
├── infrastructure
│   ├── README.md
│   ├── backend.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── platform.tfvars
│   ├── variables.tf
│   └── versions.tf
├── modules
│   ├── gke-autopilot-private-cluster
│   ├── gke-autopilot-public-cluster
│   ├── gke-standard-private-cluster
│   ├── gke-standard-public-cluster
│   ├── jupyter
│   ├── jupyter_iap
│   ├── jupyter_service_accounts
│   ├── kuberay-cluster
│   ├── kuberay-logging
│   ├── kuberay-monitoring
│   ├── kuberay-operator
│   └── kuberay-serviceaccounts
└── tutorial.md
```

To deploy new GKE cluster update the `platform.tfvars` file with the appropriate values and then execute below terraform commands:
```
terraform init
terraform apply -var-file platform.tfvars
```


## Applications

The repo structure looks like this:

```bash
.
├── LICENSE
├── Makefile
├── README.md
├── applications
│   ├── jupyter
│   └── ray
├── contributing.md
├── dcgm-on-gke
│   ├── grafana
│   └── quickstart
├── gke-a100-jax
│   ├── Dockerfile
│   ├── README.md
│   ├── build_push_container.sh
│   ├── kubernetes
│   └── train.py
├── gke-batch-refarch
│   ├── 01_gke
│   ├── 02_platform
│   ├── 03_low_priority
│   ├── 04_high_priority
│   ├── 05_compact_placement
│   ├── 06_jobset
│   ├── Dockerfile
│   ├── README.md
│   ├── cloudbuild-create.yaml
│   ├── cloudbuild-destroy.yaml
│   ├── create-platform.sh
│   ├── destroy-platform.sh
│   └── images
├── gke-disk-image-builder
│   ├── README.md
│   ├── cli
│   ├── go.mod
│   ├── go.sum
│   ├── imager.go
│   └── script
├── gke-dws-examples
│   ├── README.md
│   ├── dws-queues.yaml
│   ├── job.yaml
│   └── kueue-manifests.yaml
├── gke-online-serving-single-gpu
│   ├── README.md
│   └── src
├── gke-tpu-examples
│   ├── single-host-inference
│   └── training
├── indexed-job
│   ├── Dockerfile
│   ├── README.md
│   └── mnist.py
├── jobset
│   └── pytorch
├── modules
│   ├── gke-autopilot-private-cluster
│   ├── gke-autopilot-public-cluster
│   ├── gke-standard-private-cluster
│   ├── gke-standard-public-cluster
│   ├── jupyter
│   ├── jupyter_iap
│   ├── jupyter_service_accounts
│   ├── kuberay-cluster
│   ├── kuberay-logging
│   ├── kuberay-monitoring
│   ├── kuberay-operator
│   └── kuberay-serviceaccounts
├── saxml-on-gke
│   ├── httpserver
│   └── single-host-inference
├── training-single-gpu
│   ├── README.md
│   ├── data
│   └── src
├── tutorial.md
└── tutorials
    ├── e2e-genai-langchain-app
    ├── finetuning-llama-7b-on-l4
    └── serving-llama2-70b-on-l4-gpus
```


### Jupyter Hub

This repository contains a Terraform template for running JupyterHub on Google Kubernetes Engine. We've also included some example notebooks ( under `applications/ray/example_notebooks`), including one that serves a GPT-J-6B model with Ray AIR (see here for the original notebook). To run these, follow the instructions at [applications/ray/README.md](./applications/ray/README.md) to install a Ray cluster.

This jupyter module deploys the following resources, once per user:
- JupyterHub deployment
- User namespace
- Kubernetes service accounts

Learn more [about JupyterHub on GKE here](./applications/jupyter/README.md)

### Ray

This repository contains a Terraform template for running Ray on Google Kubernetes Engine.

This module deploys the following, once per user:
- User namespace
- Kubernetes service accounts
- Kuberay cluster
- Prometheus monitoring
- Logging container

Learn more [about Ray on GKE here](./applications/ray/README.md)

## Important Considerations
- Make sure to configure terraform backend to use GCS bucket, in order to persist terraform state across different environments.


## Licensing

* The use of the assets contained in this repository is subject to compliance with [Google's AI Principles](https://ai.google/responsibility/principles/)
* See [LICENSE](/LICENSE)
