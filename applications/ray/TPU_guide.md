# TPU User Guide

This page contains instructions for how to set up Ray on GKE with TPUs. 

For general setup instructions please refer to the [README](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/ray-on-gke/README.md)
file. 

For more information about TPUs on GKE, see [this page](https://cloud.google.com/kubernetes-engine/docs/concepts/tpus).


### Installing the GKE Platform

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


### Installing the TPU Initialization Webhook

The TPU Initialization Webhook can automatically inject the `TPU_WORKER_ID` and `TPU_WORKER_HOSTNAMES` environment variables necessary for multi-host TPU clusters. The webhook needs to be installed once per GKE cluster. The instructions can be found [here](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/main/ray-on-gke/kuberay-tpu-webhook).


### Creating the Kuberay Cluster

1. Get the GKE cluster name and location/region from `gke-platform/variables.tf`.
   Run `gcloud container clusters get-credentials %gke_cluster_name% --location=%location%`
   Configuring `gcloud` [instructions](https://cloud.google.com/sdk/docs/initializing)

2. `cd ../user`

3. Edit `variables.tf` with your GCP settings. The `<your user name>` that you specify will become a K8s namespace for your Ray services.

4. Set `enable_tpu` to `true`.
   
5. Run `terraform init`

6. Run `terraform apply`

This should deploy a Kuberay cluster with a single TPU worker node (v4 TPU with `2x2x1` topology). 

To deploy a multi-host Ray Cluster, modify `tpu_topology` [here](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/gke-platform/modules/gke_standard/main.tf#L162) as well as the Kuberay cluster spec [here](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/ray-on-gke/user/modules/kuberay/kuberay-tpu-values.yaml#L189).


### Running Sample Workloads

Install Jupyterhub according to the instructions in the [README](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/ray-on-gke/README.md).

A basic JAX program can be found [here](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/ray-on-gke/example_notebooks/jax-tpu.ipynb).

For a more advanced workload running Stable Diffusion on TPUs, see [here](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/ray-on-gke/example_notebooks/stable-diffusion-tpu.ipynb).


### (Optional) Initializing JAX Environment Manually

To manually set JAX environment variables for `TPU_WORKER_ID` and `TPU_WORKER_HOSTNAMES` before initializing JAX without using the webhook, run the following sample code:

```
@ray.remote(resources={"google.com/tpu": 4})
def get_hostname():
    import time
    time.sleep(1)
    return ray.util.get_node_ip_address()


@ray.remote(resources={"google.com/tpu": 4})
def init_tpu_env_from_ray(id_hostname_map):
    import os
    import time
    
    time.sleep(1)
    hostname = ray.util.get_node_ip_address()
    worker_id = id_hostname_map[hostname]
    
    os.environ["TPU_WORKER_ID"] = str(worker_id)
    os.environ["TPU_WORKER_HOSTNAMES"] = ",".join(list(id_hostname_map))

    return "TPU_WORKER_ID: " + os.environ["TPU_WORKER_ID"] + " TPU_WORKER_HOSTNAMES: " + os.environ["TPU_WORKER_HOSTNAMES"]


def init_jax_from_ray(num_workers: int):
    results = ray.get([get_hostname.remote() for x in range(num_workers)])
    id_hostname_map = {
        hostname: worker_id for worker_id, hostname in enumerate(set(results))}

    result = [init_tpu_env_from_ray.remote(id_hostname_map) for _ in range(num_workers)]
    print(ray.get(result))


init_jax_from_ray(num_workers=2)

``` 
