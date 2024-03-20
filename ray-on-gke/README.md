# Ray on GKE

This directory contains examples, guides and best practices for running [Ray](https://www.ray.io/) on Google Kubernetes Engine.
Most examples use the [`applications/ray`](/applications/ray) terraform module to install KubeRay and deploy RayCluster resources.

## Getting Started

### Create a RayCluster on an existing cluster

Edit `templates/workloads.tfvars` with your environment specific variables and configurations.
The following variables are required:
* project_id
* cluster_name
* cluster_location

Run the following commands to install KubeRay and deploy a Ray cluster onto your existing cluster.
```
cd templates/
terraform init
terraform apply --var-file=workloads.tfvars
```

**NOTE**: you can also create a new GKE cluster by specifying `create_cluster: true`.

Validate that the RayCluster is ready:
```
$ kubectl get raycluster
NAME                  DESIRED WORKERS   AVAILABLE WORKERS   STATUS   AGE
example-cluster-kuberay   1                 1                   ready    3m41s
```

### Install Ray

Ensure Ray is installed in your environment. See [Installing Ray](https://docs.ray.io/en/latest/ray-overview/installation.html) for more details.

### Submit a Ray job

To submit a Ray job, first establish a connection to the Ray head. For this example we'll use `kubectl port-forward`
to connect to the Ray head via localhost.

```bash
$ kubectl port-forward --address 0.0.0.0 service/example-cluster-kuberay-head-svc 8265:8265 &
```

Submit a Ray job that prints resources available in your Ray cluster:
```bash
$ ray job submit --address http://localhost:8265 -- python -c "import ray; ray.init(); print(ray.cluster_resources())"
Job submission server address: http://localhost:8265

-------------------------------------------------------
Job 'raysubmit_4JBD9mLhh9sjqm8g' submitted successfully
-------------------------------------------------------

Next steps
  Query the logs of the job:
    ray job logs raysubmit_4JBD9mLhh9sjqm8g
  Query the status of the job:
    ray job status raysubmit_4JBD9mLhh9sjqm8g
  Request the job to be stopped:
    ray job stop raysubmit_4JBD9mLhh9sjqm8g

Tailing logs until the job exits (disable with --no-wait):
2024-03-19 20:46:28,668 INFO worker.py:1405 -- Using address 10.80.0.19:6379 set in the environment variable RAY_ADDRESS
2024-03-19 20:46:28,668 INFO worker.py:1540 -- Connecting to existing Ray cluster at address: 10.80.0.19:6379...
2024-03-19 20:46:28,677 INFO worker.py:1715 -- Connected to Ray cluster. View the dashboard at 10.80.0.19:8265
{'node:__internal_head__': 1.0, 'object_store_memory': 2295206707.0, 'memory': 8000000000.0, 'CPU': 4.0, 'node:10.80.0.19': 1.0}
Handling connection for 8265

------------------------------------------
Job 'raysubmit_4JBD9mLhh9sjqm8g' succeeded
------------------------------------------
```

### Ray Client for interactive sessions

The RayClient API enables Python scripts to interactively connect to remote Ray clusters. See [Ray Client](https://docs.ray.io/en/latest/cluster/running-applications/job-submission/ray-client.html) for more details.

To use the client, first establish a connection to the Ray head. For this example we'll use `kubectl port-forward`
to connect to the Ray head Service via localhost.

```bash
$ kubectl port-forward --address 0.0.0.0 service/example-cluster-kuberay-head-svc 10001:10001 &
```

Next, define a Python script containing remote code you want to run on your Ray cluster. Similar to the previous example,
this remote function will print the resources available in the cluster:
```python
# cluster_resources.py
import ray

ray.init("ray://localhost:10001")

@ray.remote
def cluster_resources():
  return ray.cluster_resources()

print(ray.get(cluster_resources.remote()))
```

Run the Python script:
```
$ python cluster_resources.py
{'CPU': 4.0, 'node:__internal_head__': 1.0, 'object_store_memory': 2280821145.0, 'node:10.80.0.22': 1.0, 'memory': 8000000000.0}
```

## Guides & Tutorials

See the following guides and tutorials for running Ray applications on GKE:
* [Getting Started with KubeRay](https://docs.ray.io/en/latest/cluster/kubernetes/getting-started.html)
* [Serve an LLM on L4 GPUs with Ray](https://cloud.google.com/kubernetes-engine/docs/how-to/serve-llm-l4-ray)
* [Logging & Monitoring for Ray clusters](./guides/observability)
* [TPU Guide](./guides/tpu/)
* [Priority Scheduling with RayJob and Kueue](https://docs.ray.io/en/master/cluster/kubernetes/examples/rayjob-kueue-priority-scheduling.html)
* [Gang Scheduling with RayJob and Kueue](https://docs.ray.io/en/master/cluster/kubernetes/examples/rayjob-kueue-gang-scheduling.html)
* [RayTrain with GCSFuse CSI driver](./guides/raytrain-with-gcsfusecsi/)

## Blogs & Best Practices

* [Getting started with Ray on Google Kubernetes Engine](https://cloud.google.com/blog/products/containers-kubernetes/use-ray-on-kubernetes-with-kuberay)
* [Why GKE for your Ray AI workloads?](https://cloud.google.com/blog/products/containers-kubernetes/the-benefits-of-using-gke-for-running-ray-ai-workloads)
* [Advanced scheduling for AI/ML with Ray and Kueue](https://cloud.google.com/blog/products/containers-kubernetes/using-kuberay-and-kueue-to-orchestrate-ray-applications-in-gke)
* [4 ways to reduce cold start latency on Google Kubernetes Engine](https://cloud.google.com/blog/products/containers-kubernetes/tips-and-tricks-to-reduce-cold-start-latency-on-gke)
