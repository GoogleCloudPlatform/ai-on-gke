# Ray on GKE

This repository contains a Terraform template for running [Ray](https://www.ray.io/) on Google Kubernetes Engine.
We've also included some example notebooks (`ai-on-gke/ray-on-gke/example_notebooks`), including one that serves a GPT-J-6B model with Ray AIR (see
[here](https://docs.ray.io/en/master/ray-air/examples/gptj_serving.html) for the original notebook).

This module assumes you already have a functional GKE cluster. If not, follow the instructions under `ai-on-gke/gke-platform/README.md`
to install a Standard or Autopilot GKE cluster, then follow the instructions in this module to install Ray. 

This module deploys the following, once per user:
* User namespace
* Kubernetes service accounts
* Kuberay cluster
* Prometheus monitoring
* Logging container

## Installation

Preinstall the following on your computer:
* Kubectl
* Terraform 
* Helm
* Gcloud

> **_NOTE:_** Terraform keeps state metadata in a local file called `terraform.tfstate`. Deleting the file may cause some resources to not be cleaned up correctly even if you delete the cluster. We suggest using `terraform destory` before reapplying/reinstalling.

1. If needed, git clone https://github.com/GoogleCloudPlatform/ai-on-gke

2. `cd applications/ray`

3. Edit `workloads.tfvars` with your GCP settings. The `<your user name>` that you specify will become a K8s namespace for your Ray services.

4. Run `terraform init`

5. Find the name and location of the GKE cluster you want to use.
   Run `gcloud container clusters list --project=<your GCP project>` to see all the available clusters.
   _Note: If you created the GKE cluster via the ai-on-gke/gke-platform repo, you can get the cluster info from `ai-on-gke/gke-platform/variables.tf`_

6. Run `gcloud container clusters get-credentials %gke_cluster_name% --location=%location%`
   Configuring `gcloud` [instructions](https://cloud.google.com/sdk/docs/initializing)

7. Run `terraform apply`

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

## Using Ray with Jupyter

If you want to connect to the Ray cluster via a Jupyter notebook or to try the example notebooks in the repo, please
first install JupyterHub via `ai-on-gke/jupyter-on-gke/README.md`.

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
