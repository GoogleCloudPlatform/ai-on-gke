# Running Flyte on GKE

This guide will show how to install Flyte using Helm on GKE cluster.

## Overview
Here we will show how to install Flyte on GKE. This tutorial will use CloudSql PostgreSQL database as database and GCS Bucket as storage. 

## Before you begin
1. Ensure you have a gcp project with billing enabled and [enabled the GKE API](https://cloud.google.com/kubernetes-engine/docs/how-to/enable-gkee). 

2. Ensure you have the following tools installed on your workstation
* [gcloud CLI](https://cloud.google.com/sdk/docs/install)
* [gcloud kubectl](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_kubectl)
* [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
* [yq](https://github.com/mikefarah/yq/#install)

## Setting up your GKE cluster with Terraform
1. Create a `.tfvar` file with the neccessary variables for our environment.Then copy the values from `example_environment.tfvars`. Make sure you change the values especially the name:

```hcl
cluster_name = "skypilot-tutorial"
```
Also if you would like to use GCS bucket for terraform state please create a bucket manually and then uncomment the contents of `backend.tf` and specify your bucket:
```hcl
terraform {
   backend "gcs" {
     bucket = "flyte-tfstate-bucket"
     prefix = "terraform/state/flyte_tutorial"
   }
 }
```
2. Initialize the modules
```bash
terraform init
```
3. Apply while referencing the `.tfvar` file we created
```bash
terraform apply -var-file=your_environment.tfvar
```
## Get kubernetes access
1. Fetch the kubeconfig file by running:
```bash
gcloud container clusters get-credentials $(terraform output -raw gke_cluster_name) --region $(terraform output -raw gke_cluster_location) --project $(terraform output -raw project_id)
```
## Get the needed variables for Helm Value file
```
terrafrom output

## Cleanup
1. Destory the provisioned infrastructure
```bash
terraform destroy -var-file=your_environment.tfvar
```