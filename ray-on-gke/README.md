# Ray on GKE

This repository contains a Terraform template for running [Ray](https://www.ray.io/) on Google Kubernetes Engine.
We've also included some example notebooks, including one that serves a GPT-J-6B model with Ray AIR (see
[here](https://docs.ray.io/en/master/ray-air/examples/gptj_serving.html) for the original notebook).

The solution is split into `platform` and `user` resources. 

Platform resources (deployed once):
* GKE Cluster
* Nvidia GPU drivers
* Kuberay operator and CRDs

User resources (deployed once per user):
* User namespace
* Kubernetes service accounts
* Kuberay cluster
* Prometheus monitoring
* Logging container
* Jupyter notebook

## Installation

Preinstall the following on your computer:
* Kubectl
* Terraform 
* Helm
* Gcloud

Note: Terraform keeps state metadata in a local file called `terraform.tfstate`.
If you need to reinstall any resources, make sure to delete this file as well.

### Platform

1. git clone https://github.com/GoogleCloudPlatform/ai-on-gke

2. `cd ray-on-gke/platform`

3. Edit `variables.tf` with your GCP settings.

4. Run `terraform init`

5. Run `terraform apply`

### User

1. `cd user`

2. Edit `variables.tf` with your GCP settings. The `<your user name>` that you specify will become a K8s namespace for your Ray services.

3. Run `terraform init`

4. Get the GKE cluster name and location/region from `platform/variables.tf`.
   Run `gcloud container clusters get-credentials %gke_cluster_name% --location=%location%`
   Configuring `gcloud` [instructions](https://cloud.google.com/sdk/docs/initializing)

5. Run `terraform apply`

## Using Ray with Jupyter

1. Run `kubectl get services -n <namespace>`. The namespace is the user name that you specified above.

2. Copy the external IP for the notebook.

3. Open the external IP in a browser and login. The default user names and
   passwords can be found in the [Jupyter
   settings](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/ray-on-gke/user/modules/jupyterhub/jupyterhub-values.yaml) file.

4. The Ray cluster is available at `ray://example-cluster-kuberay-head-svc:10001`. To access the cluster, you can open one of the sample notebooks under `example_notebooks` (via `File` -> `Open from URL` in the Jupyter notebook window and use the raw file URL from GitHub) and run through the example. Ex url: https://raw.githubusercontent.com/GoogleCloudPlatform/ai-on-gke/main/ray-on-gke/example_notebooks/gpt-j-online.ipynb

5. To use the Ray dashboard, run the following command to port-forward:
```
kubectl port-forward -n <namespace> service/example-cluster-kuberay-head-svc 8265:8265
```

And then open the dashboard using the following URL:
```
http://localhost:8265
```

## Using Ray with Ray Jobs API

1. To connect to the remote GKE cluster with the Ray API, setup the Ray dashboard.
Run the following command to port-forward:
```
kubectl port-forward -n <namespace> service/example-cluster-kuberay-head-svc 8265:8265
```

And then open the dashboard using the following URL:
```
http://localhost:8265
```

2. Set the RAY_ADDRESS environment variable:
`export RAY_ADDRESS="http://127.0.0.1:8265"` 

3. Create a working directory with some job file `ray_job.py`.

4. Submit the job:
`ray job submit --working-dir %your_working_directory% -- python ray_job.py`

5. Note the job submission ID from the output, eg.:
`Job 'raysubmit_inB2ViQuE29aZRJ5' succeeded`

See [Ray docs](https://docs.ray.io/en/latest/cluster/running-applications/job-submission/quickstart.html#submitting-a-job) for more info.

## Securing Your Cluster Endpoints

For demo purposes, this repo creates a public IP for the Jupyter notebook with basic dummy authentication. To secure your cluster, it is *strong recommended* to replace
this with your own secure endpoints. 

For more information, please take a look at the following links:
* https://cloud.google.com/iap/docs/enabling-kubernetes-howto
* https://cloud.google.com/endpoints/docs/openapi/get-started-kubernetes-engine
* https://jupyterhub.readthedocs.io/en/stable/tutorial/getting-started/authenticators-users-basics.html


## Running GPT-J-6B

This example is adapted from Ray AIR's examples [here](https://docs.ray.io/en/master/ray-air/examples/gptj_serving.html).

1. Open the `gpt-j-online.ipynb` notebook.

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
3. If using Ray Jobs API:
(a) Note the job ID returned by the `ray job submit` API.
Eg: Job submission: `ray job submit --working-dir /Users/imreddy/ray_working_directory  -- python script.py`
    Job submission ID: `Job 'raysubmit_kFWB6VkfyqK1CbEV' submitted successfully`
(b) Get the namespace name from `user/variables.tf` or `kubectl get namespaces`
(c) Use the following query to search for the job logs:

```
resource.labels.namespace_name=%NAMESPACE_NAME%
jsonpayload.job_id=%RAY_JOB_ID%
```

To see monitoring metrics:
1. Open Cloud Console and open Metrics Explorer
2. In "Target", select "Prometheus Target" and then "Ray".
3. Select the metric you want to view, and then click "Apply".
