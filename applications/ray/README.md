# Ray on GKE Templates

This repository contains a Terraform template for running [Ray](https://www.ray.io/) on Google Kubernetes Engine.
See the [Ray on GKE](/ray-on-gke/) directory to see additional guides and references.

## Installation

Preinstall the following on your computer:
* Terraform
* Gcloud

> **_NOTE:_** Terraform keeps state metadata in a local file called `terraform.tfstate`. Deleting the file may cause some resources to not be cleaned up correctly even if you delete the cluster. We suggest using `terraform destory` before reapplying/reinstalling.

1. If needed, git clone https://github.com/GoogleCloudPlatform/ai-on-gke

2. `cd applications/ray`

3. Find the name and location of the GKE cluster you want to use.
   Run `gcloud container clusters list --project=<your GCP project>` to see all the available clusters.
   _Note: If you created the GKE cluster via the infrastructure repo, you can get the cluster info from `platform.tfvars`_

4. Edit `workloads.tfvars` with your environment specific variables and configurations.

5. Run `terraform init && terraform apply --var-file workloads.tfvars`