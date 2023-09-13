# TPU User Guide

This page contains instructions for how to set up Ray on GKE with TPUs. 

For general setup instructions please refer to the [README](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/ray-on-gke/README.md)
file. 

For more information about TPUs on GKE, see [this page](https://cloud.google.com/kubernetes-engine/docs/concepts/tpus).


### Platform

1. If needed, git clone https://github.com/GoogleCloudPlatform/ai-on-gke

2. `cd ai-on-gke/gke-platform`

3. Edit `variables.tf` with your GCP settings.

4. Change the region or zone to one where TPUs are available (see [this link](https://cloud.google.com/tpu/docs/regions-zones) for details.
For v4 TPUs (the default type), the region should be set to `us-central2` or `us-central2-b`.

5. Set the following flags (note that TPUs are currently only supported on GKE standard):

```
variable "enable_autopilot" {
  type        = bool
  description = "Set to true to enable GKE Autopilot clusters"
  default     = false
}

variable "enable_tpu" {
  type        = bool
  description = "Set to true to create TPU node pool"
  default     = true
}
```
 
6. Run `terraform init`

7. Run `terraform apply`

### User

1. Get the GKE cluster name and location/region from `gke-platform/variables.tf`.
   Run `gcloud container clusters get-credentials %gke_cluster_name% --location=%location%`
   Configuring `gcloud` [instructions](https://cloud.google.com/sdk/docs/initializing)

2. `cd ../user`

3. Edit `variables.tf` with your GCP settings. The `<your user name>` that you specify will become a K8s namespace for your Ray services.

4. Set `enable_tpu` to `true`.
   
5. Run `terraform init`

6. Run `terraform apply`

This should deploy a Kuberay cluster with a single TPU worker node (v4 TPU with `2x2x1` topology). 


### Running Sample Workloads

Install Jupyterhub according to the instructions in the [README](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/ray-on-gke/README.md).

A basic JAX program can be found [here](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/ray-on-gke/example_notebooks/jax-tpu.ipynb).

For a more advanced workload running Stable Diffusion on TPUs, see [here](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/ray-on-gke/example_notebooks/stable-diffusion-tpu.ipynb).

