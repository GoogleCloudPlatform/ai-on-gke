# Ray on GKE

This repository contains a Terraform template for installing a Standard or Autopilot GKE cluster in your GCP project.
It sets up the cluster to work seamlessly with the `ray-on-gke` and `jupyter-on-gke` modules in the `ai-on-gke` repo.

Platform resources:
* GKE Cluster
* Nvidia GPU drivers
* Kuberay operator and CRDs

## Installation

Preinstall the following on your computer:
* Kubectl
* Terraform 
* Helm
* Gcloud

> **_NOTE:_** Terraform keeps state metadata in a local file called `terraform.tfstate`. If you need to reinstall any resources, make sure to delete this file as well.

### Platform

1. If needed, git clone https://github.com/GoogleCloudPlatform/ai-on-gke

2. `cd ai-on-gke/gke-platform`

3. Edit `variables.tf` with your GCP settings.

4. Run `terraform init`

5. Run `terraform apply`
