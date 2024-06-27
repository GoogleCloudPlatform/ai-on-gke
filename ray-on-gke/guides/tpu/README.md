# TPU User Guide

This page contains instructions for how to set up Ray on GKE with TPUs. 


### Prerequisites

Please follow the official [Google Cloud documentation](https://cloud.google.com/tpu/docs/tpus-in-gke) for an introduction to TPUs. In partiuclar, please ensure that your GCP project has sufficient quotas to provision the cluster, see [this link](https://cloud.google.com/tpu/docs/tpus-in-gke#ensure-quotas) for details.

For addition useful information about TPUs on GKE (such as topology configurations and availability), see [this page](https://cloud.google.com/kubernetes-engine/docs/concepts/tpus).

In addition, please ensure the following are installed on your local development environment:
* Helm (v3.9.3)
* Terraform (v1.7.4)
* Kubectl

### Provisioning a GKE Cluster with Terraform (Optional)

Skip this section if you already have a GKE cluster with TPUs (cluster version should be 1.28 or later). 

1. `git clone https://github.com/GoogleCloudPlatform/ai-on-gke`

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


### Manually Installing the TPU Initialization Webhook

The TPU Initialization Webhook automatically bootstraps the TPU environment for TPU clusters. The webhook needs to be installed once per GKE cluster and requires a Kuberay Operator running v1.1+ and GKE cluster version of 1.28+. The webhook requires [cert-manager](https://github.com/cert-manager/cert-manager) to be installed in-cluster to handle TLS certificate injection. cert-manager can be installed in both GKE standard and autopilot clusters using the following helm commands:
```
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install --create-namespace --namespace cert-manager --set installCRDs=true --set global.leaderElection.namespace=cert-manager cert-manager jetstack/cert-manager
```
After installing cert-manager, it may take up to two minutes for the certificate to become ready.

Installing the webhook:
1. `git clone https://github.com/GoogleCloudPlatform/ai-on-gke`
2. `cd ai-on-gke/ray-on-gke/tpu/kuberay-tpu-webhook`
3. `make deploy`
    - this will create the webhook deployment, configs, and service in the "ray-system" namespace
    - to change the namespace, edit the "namespace" value in each .yaml in deployments/ and certs/
4. `make deploy-cert`

For common errors encountered when deploying the webhook, see the [Troubleshooting guide](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/main/applications/ray/kuberay-tpu-webhook/Troubleshooting.md).

### Creating the Kuberay Cluster

You can find sample TPU cluster manifests for [single-host](https://github.com/ray-project/kuberay/blob/master/ray-operator/config/samples/ray-cluster.tpu-v4-singlehost.yaml) and [multi-host](https://github.com/ray-project/kuberay/blob/master/ray-operator/config/samples/ray-cluster.tpu-v4-multihost.yaml) here.

If you are using Terraform:

1. Get the GKE cluster name and location/region from `infrastructure/platform.tfvars`.
   Run `gcloud container clusters get-credentials %gke_cluster_name% --location=%location%`.
   Configuring `gcloud` [instructions](https://cloud.google.com/sdk/docs/initializing)

2. `cd ../applications/ray`

3. Edit `workloads.tfvars` with your GCP settings. Replace `<your project ID>` and `<your cluster name>` with the names you used in `platform.tfvars`.

4. Run `terraform init && terraform apply -var-file workloads.tfvars`

This should deploy a Kuberay cluster with a single TPU worker node (v4 TPU with `2x2x1` topology). 

To deploy a multi-host Ray Cluster, modify the `worker` spec [here](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/modules/kuberay-cluster/kuberay-tpu-values.yaml) by changing the `cloud.google.com/gke-tpu-topology` `nodeSelector` to a multi-host topology. Set the `numOfHosts` field in the `worker` spec to the number of hosts specified by your chosen topology. For v4 TPUs, each TPU VM has access to 4 TPU chips. Therefore, you can calculate the number of TPU VM hosts by taking the product of the topology and dividing by 4 (i.e. a 2x2x4 TPU podslice will have 4 TPU VM hosts).

### Running Sample Workloads

1. Save the following to a local file (e.g. `test_tpu.py`):
```
import ray

ray.init(
    address="ray://ray-cluster-kuberay-head-svc:10001",
    runtime_env={
        "pip": [
            "jax[tpu]==0.4.12",
            "-f https://storage.googleapis.com/jax-releases/libtpu_releases.html",
        ]
    }
)


@ray.remote(resources={"TPU": 4})
def tpu_cores():
    import jax
    return "TPU cores:" + str(jax.device_count())

num_workers = 4
result = [tpu_cores.remote() for _ in range(num_workers)]
print(ray.get(result))
```
2. `kubectl port-forward svc/ray-cluster-kuberay-head-svc 8265:8265 &`
3. `export RAY_ADDRESS=http://localhost:8265`
4. `ray job submit --runtime-env-json='{"working_dir": "."}' -- python test_tpu.py`
   
For a more advanced workload running Stable Diffusion on TPUs, see [here](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/applications/ray/example_notebooks/stable-diffusion-tpu.ipynb).

 
