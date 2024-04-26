# Ray on GKE Templates

This repository contains a Terraform template for running [Ray](https://www.ray.io/) on Google Kubernetes Engine.
See the [Ray on GKE](/ray-on-gke/) directory to see additional guides and references.

## Prerequisites

1. GCP Project with following APIs enabled
    - container.googleapis.com
    - iap.googleapis.com (required when using authentication with Identity Aware Proxy)

2. A functional GKE cluster.
    - To create a new standard or autopilot cluster, follow the instructions in [`infrastructure/README.md`](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/infrastructure/README.md)
    - Alternatively, you can set the `create_cluster` variable to true in `workloads.tfvars` to provision a new GKE cluster. This will default to creating a GKE Autopilot cluster; if you want to provision a standard cluster you must also set `autopilot_cluster` to false.

3. This module is configured to optionally use Identity Aware Proxy (IAP) to protect access to the Ray dashboard. It expects the brand & the OAuth consent configured in your org. You can check the details here: [OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent)

4. Preinstall the following on your computer:
    * Terraform
    * Gcloud CLI

## Installation

### Configure Inputs

1. If needed, clone the repo
```
git clone https://github.com/GoogleCloudPlatform/ai-on-gke
cd ai-on-gke/applications/ray
```

2. Edit `workloads.tfvars` with your GCP settings.

**Important Note:**
If using this with the Jupyter module (`applications/jupyter/`), it is recommended to use the same k8s namespace
for both i.e. set this to the same namespace as `applications/jupyter/workloads.tfvars`.

| Variable                    | Description                                                                                                    | Required |
|-----------------------------|----------------------------------------------------------------------------------------------------------------|:--------:|
| project_id                  | GCP Project Id                                                                                                 | Yes      |
| cluster_name                | GKE Cluster Name                                                                                               | Yes      |
| cluster_location            | GCP Region                                                                                                     | Yes      |
| kubernetes_namespace        | The namespace that Ray and rest of the other resources will be installed in.                                   | Yes      |
| gcs_bucket                  | GCS bucket to be used for Ray storage                                                                          | Yes      |
| create_service_account      | Create service accounts used for Workload Identity mapping                                                     | Yes      |


### Install

> **_NOTE:_** Terraform keeps state metadata in a local file called `terraform.tfstate`. Deleting the file may cause some resources to not be cleaned up correctly even if you delete the cluster. We suggest using `terraform destory` before reapplying/reinstalling.

3. Ensure your gcloud application default credentials are in place. 
```
gcloud auth application-default login
```

4. Run `terraform init`

5. Run `terraform apply --var-file=./workloads.tfvars`. 

