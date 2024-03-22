# TPU User Guide

This page contains instructions for how to set up Ray on GKE with TPUs. 

For general setup instructions please refer to the [README](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/applications/ray/README.md)
file. 

For more information about TPUs on GKE, see [this page](https://cloud.google.com/kubernetes-engine/docs/concepts/tpus).


### Installing the GKE Platform

1. If needed, git clone https://github.com/GoogleCloudPlatform/ai-on-gke

2. `cd ai-on-gke/infrastructure`

3. Edit `platform.tfvars` with your GCP settings.

4. Change the region or zone to one where TPUs are available (see [this link](https://cloud.google.com/tpu/docs/regions-zones) for details.
For v4 TPUs (the default type), the region should be set to `us-central2` or `us-central2-b`.

5. Set the following flags (note that TPUs are currently only supported on GKE standard):

```
autopilot_cluster = false
...
enable_tpu = true
```
 
6. Change the following lines in the `tpu_pools` configuration to match your desired [TPU accelerator](https://cloud.google.com/tpu/docs/supported-tpu-configurations#using-accelerator-type).
```
accelerator_count      = 2
accelerator_type       = "nvidia-tesla-t4"
```

7. Run `terraform init && terraform apply -var-file platform.tfvars`


### Installing the TPU Initialization Webhook

The TPU Initialization Webhook automatically injects the `TPU_WORKER_ID`, `TPU_NAME`, and `TPU_WORKER_HOSTNAMES` environment variables necessary for multi-host TPU clusters. The webhook needs to be installed once per GKE cluster and requires a Kuberay Operator running v1.1 and GKE cluster version of 1.28+. The instructions can be found [here](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/applications/ray/kuberay-tpu-webhook).

### Creating the Kuberay Cluster

1. Get the GKE cluster name and location/region from `infrastructure/platform.tfvars`.
   Run `gcloud container clusters get-credentials %gke_cluster_name% --location=%location%`.
   Configuring `gcloud` [instructions](https://cloud.google.com/sdk/docs/initializing)

2. `cd ../applications/ray`

3. Edit `workloads.tfvars` with your GCP settings. Replace `<your project ID>` and `<your cluster name>` with the names you used in `platform.tfvars`.

4. Run `terraform init && terraform apply -var-file workloads.tfvars`

This should deploy a Kuberay cluster with a single TPU worker node (v4 TPU with `2x2x1` topology). 

To deploy a multi-host Ray Cluster, modify the `worker` spec [here](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/modules/kuberay-cluster/kuberay-tpu-values.yaml) by changing the `cloud.google.com/gke-tpu-topology` `nodeSelector` to a multi-host topology. Set the `numOfHosts` field in the `worker` spec to the number of hosts specified by your chosen topology. For v4 TPUs, each TPU VM has access to 4 TPU chips. Therefore, you can calculate the number of TPU VM hosts by taking the product of the topology and dividing by 4 (i.e. a 2x2x4 TPU podslice will have 4 TPU VM hosts).

### Running Sample Workloads

Install JupyterHub according to the instructions in the [README](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/applications/jupyter/README.md).

A basic JAX program can be found [here](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/applications/ray/example_notebooks/jax-tpu.ipynb).

For a more advanced workload running Stable Diffusion on TPUs, see [here](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/applications/ray/example_notebooks/stable-diffusion-tpu.ipynb).


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
