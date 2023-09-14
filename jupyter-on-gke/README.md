# JupyterHub on GKE

This repository contains a Terraform template for running [JupyterHub](https://jupyter.org/hub) on Google Kubernetes Engine.

This module assumes you already have a functional GKE cluster. If not, follow the instructions under `ai-on-gke/gke-platform/README.md`
to install a Standard or Autopilot GKE cluster, then follow the instructions in this module to install JupyterHub. 

We've also included some example notebooks (`ai-on-gke/ray-on-gke/example_notebooks`), including one that serves a GPT-J-6B model with Ray AIR (see
[here](https://docs.ray.io/en/master/ray-air/examples/gptj_serving.html) for the original notebook). To run these, follow the instructions at
`ai-on-gke/ray-on-gke/README.md` to install a Ray cluster.

This module deploys the following resources, once per user:
* JupyterHub deployment
* User namespace
* Kubernetes service accounts

## Installation

Preinstall the following on your computer:
* Kubectl
* Terraform 
* Helm
* Gcloud

> **_NOTE:_** Terraform keeps state metadata in a local file called `terraform.tfstate`. If you need to reinstall any resources, make sure to delete this file as well.

### JupyterHub

> **_NOTE:_** Currently the cd/user/jupyterhub/jupyter_config/config.yaml has 3 profiles that uses the same jupyter images, this can be changed, as well as the description of these profiles.

1. If needed, git clone https://github.com/GoogleCloudPlatform/ai-on-gke

2. `cd ai-on-gke/jupyter-on-gke/`

3. Edit `variables.tf` with your GCP settings. The `<your user name>` that you specify will become a K8s namespace for your Jupyterhub services.
Note:
If using this with the Ray module (`ai-on-gke/ray-on-gke/`), it is recommended to use the same k8s namespace
for both i.e. set this to the same namespace as `ai-on-gke/ray-on-gke/user/variables.tf`.
If not, set `enable_create_namespace` to `true` so a new k8s namespace is created for the Jupyter resources.

4. Run `terraform init`

5. Find the name and location of the GKE cluster you want to use.
   Run `gcloud container clusters list --project=<your GCP project> to see all the available clusters.
   Note: If you created the GKE cluster via the ai-on-gke/gke-platform repo, you can get the cluster info from `ai-on-gke/gke-platform/variables.tf`

6. Run `gcloud container clusters get-credentials %gke_cluster_name% --location=%location%`
   Configuring `gcloud` [instructions](https://cloud.google.com/sdk/docs/initializing)

7. Run `terraform apply`

## Using Ray with Jupyter

1. Run `kubectl get services -n <namespace>`. The namespace is the user name that you specified above.

2. Copy the external IP for the notebook.

3. Open the external IP in a browser and login. The default user names and
   passwords can be found in the [Jupyter
   settings](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/jupyter-on-gke/jupyter_config/jupyter_config/config.yaml) file.

4. The Ray cluster is available at `ray://example-cluster-kuberay-head-svc:10001`. To access the cluster, you can open one of the sample notebooks under `example_notebooks` (via `File` -> `Open from URL` in the Jupyter notebook window and use the raw file URL from GitHub) and run through the example. Ex url: https://raw.githubusercontent.com/GoogleCloudPlatform/ai-on-gke/main/ray-on-gke/example_notebooks/gpt-j-online.ipynb

5. To use the Ray dashboard, run the following command to port-forward:
```
kubectl port-forward -n <namespace> service/example-cluster-kuberay-head-svc 8265:8265
```

And then open the dashboard using the following URL:
```
http://localhost:8265
```

## Securing Your Cluster Endpoints

For demo purposes, this repo creates a public IP for the Jupyter notebook with basic dummy authentication. To secure your cluster, it is *strong recommended* to replace
this with your own secure endpoints. 

For more information, please take a look at the following links:
* https://cloud.google.com/iap/docs/enabling-kubernetes-howto
* https://cloud.google.com/endpoints/docs/openapi/get-started-kubernetes-engine
* https://jupyterhub.readthedocs.io/en/stable/tutorial/getting-started/authenticators-users-basics.html


## Running GPT-J-6B

This example is adapted from Ray AIR's examples [here](https://docs.ray.io/en/master/ray-air/examples/gptj_serving.html).

1. Open the `gpt-j-online.ipynb` notebook under `ai-on-gke/ray-on-gke/example_notebooks`.

2. Open a terminal in the Jupyter session and install Ray AIR:
```
pip install ray[air]
```

3. Run through the notebook cells. You can change the prompt in the last cell:
```
prompt = (
     ## Input your own prompt here
)
```

4. This should output a generated text response.


## Logging and Monitoring

This repository comes with out-of-the-box integrations with Google Cloud Logging
and Managed Prometheus for monitoring. To see your Ray cluster logs:

1. Open Cloud Console and open Logging
2. If using Jupyter notebook for job submission, use the following query parameters:
```
resource.type="k8s_container"
resource.labels.cluster_name=%CLUSTER_NAME%
resource.labels.pod_name=%RAY_HEAD_POD_NAME%
resource.labels.container_name="fluentbit"
```

To see monitoring metrics:
1. Open Cloud Console and open Metrics Explorer
2. In "Target", select "Prometheus Target" and then "Ray".
3. Select the metric you want to view, and then click "Apply".

# Jupyterhub Profiles

## Default Profiles

By default, there are 3 pre-set profiles for Jupyterhub:

![Profiles Page](images/image.png)

As the description for each profiles explains, each profiles uses a different resource.

1. First profile uses CPUs and uses the image: `jupyter/tensorflow-notebook` with tag `python-3.10`

2. Second profile uses 2 T4 GPUs and the image: `jupyter/tensorflow-notebook:python-3.10` with tag `python-3.10` [^1]

3. Third profile uses 2 A100 GPUs and the image: `jupyter/tensorflow-notebook:python-3.10` with tag `python-3.10` [^1]

## Editting profiles

You can change the image used by these profiles, change the resources, and add specific hooks to the profiles

Within the [`config.yaml`](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/jupyter-on-gke/jupyter_config/config.yaml), the profiles sit under the `singleuser` key:

``` yaml
singleuser:
    cpu:
        ...
    memory:
        ...
    image:
        name: jupyter/tensorflow-notebook
        tag: python-3.10
    ...
    profileList:
    ...
```

### Image

The default image used by all three of the profiles is `jupyter/tensorflow-notebook:python-3.10`

1. For profile 1, it uses the: `default: true` field. This means that all the default configs under `singleuser` are used.

2. For profile 2 and 3, the images are defined under `kubespawner_override`

``` yaml
    display_name: "Profile2 name"
        description: "description here"
        kubespawner_override:
            image: jupyter/tensorflow-notebook:python-3.10
    ...
```

Kubespanwer_override is a dictionary with overrides that gets applied through the Kubespawner. [^2]

More images of tensorflow can be found [here](https://hub.docker.com/r/jupyter/tensorflow-notebook)

### Resources

Each of the users get a part of the memory and CPU and the resources are by default:

``` yaml
    cpu:
        limit: .5
        guarantee: .5
    memory:
        limit: 1G
        guarantee: 1G
```

The *limit* if the reousrce sets a hard limit on how much of that resource can the user have.
The *guarantee* meaning the least amount of resource that will be available to the user at all times.

Similar to overriding images, the resources can also be overwritten by using `kubesparner_override`:

``` yaml
    kubespawner_override:
        cpu_limit: .7
        cpu_guarantee: .7
        mem_limit: 2G
        mem_guarantee: 2G
        nvidia.com/gpu: "2"
```

### Node/GPU

Jupyterhub config allows the use of [nodeSelector](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector). This is the way the profiles specify which node/GPU it wants

``` yaml
nodeSelector:
    iam.gke.io/gke-metadata-server-enabled: "true"
    cloud.google.com/gke-accelerator: "nvidia-tesla-t4"
```

Override using `kubespwaner_override`:

``` yaml
    kubespawner_override:
        node_selector:
          cloud.google.com/gke-accelerator: "nvidia-tesla-a100"
```

The possible GPUs are:

1. nvidia-tesla-k80
2. nvidia-tesla-p100
3. nvidia-tesla-p4
4. nvidia-tesla-v100
5. nvidia-tesla-t4
6. nvidia-tesla-a100
7. nvidia-a100-80gb
8. nvidia-l4

### Example profile

Example of a profile that overrides the default values:

``` yaml
  - display_name: "Learning Data Science"
    description: "Datascience Environment with Sample Notebooks"
    kubespawner_override:
        cpu_limit: .5
        cpu_guarantee: .5
        mem_limit: 1G
        mem_guarantee: 1G
    image: jupyter/datascience-notebook:2343e33dec46
    lifecycle_hooks:
        postStart:
        exec:
            command:
            - "sh"
            - "-c"
            - >
                gitpuller https://github.com/data-8/materials-fa17 master materials-fa;
```

### Additional Overrides

With `kubespanwer_override` there are additional overrides that could be done, including `lifecycle_hooks`, `storage_capcity`, and `storage class`
Fields can be found [here](https://jupyterhub-kubespawner.readthedocs.io/en/latest/spawner.html)

[^1]: If using Standard clusters, the cluster must have at least 2 of the GPU type ready
[^2]: More information on Kubespawner [here](https://github.com/jupyterhub/kubespawner/blob/main/kubespawner/spawner.py)
