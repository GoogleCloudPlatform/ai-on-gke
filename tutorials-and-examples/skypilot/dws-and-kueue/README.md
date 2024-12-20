# GKE capacity chasing with SkyPilot and Kueue utilizing Dynamic Workload Scheduling

This tutorial will expand on [SkyPilot Tutorial](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/main/tutorials-and-examples/skypilot) by leveraging [DWS](https://cloud.google.com/blog/products/compute/introducing-dynamic-workload-scheduler) with the help of a opensource project called [Kueue](https://kueue.sigs.k8s.io/)

## Overview
This tutorial is designed for ML scientists who plan to use SkyPilot for model traning of serving LLM models on GKE while utilizing Dynamic Workload Scheduler to aquire GPU resources when they are available. This will involve creating a GKE cluster with GPU node pools with queue processing enabled using terrafrom, installing Kueue, SkyPilot and running a model.

## Before you begin
1. Ensure you have a gcp project with billing enabled and [enabled the GKE API](https://cloud.google.com/kubernetes-engine/docs/how-to/enable-gkee). 

2. Ensure you have the following tools installed on your workstation
* [gcloud CLI](https://cloud.google.com/sdk/docs/install)
* [gcloud kubectl](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_kubectl)
* [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
* [python](https://docs.python.org/3/using/index.html)
* [venv](https://packaging.python.org/en/latest/guides/installing-using-pip-and-virtual-environments/)
* [yq](https://github.com/mikefarah/yq/#install)

## Setting up your GKE cluster with Terraform
1. Create a `.tfvar` file with the neccessary variables for our environment.Then copy the values from `example_environment.tfvars`. Make sure you change the values especially the name:

```hcl
cluster_name = "skypilot-tutorial"
```
Also if you would like to use GCS bucket for terraform state please create a bucket manually and then uncomment the contents of `backend.tf` and specify your bucket:
```hcl
terraform {
   backend "gcs" {
     bucket = "skypilot-tfstate-bucket"
     prefix = "terraform/state/skypilot_tutorial"
   }
 }
```
Make sure you have also enabled queue provisioning on the gpu pool. You can do that by adding `queued_provisioning` to the `gpu_pools` variable in the tfvar file. 
```hcl
gpu_pools = [ {
  name                = "gpu-pool"
  queued_provisioning = true
  machine_type        = "g2-standard-24"
  disk_type           = "pd-balanced"
  autoscaling         = true
  min_count           = 0
  max_count           = 3
  initial_node_count  = 0
} ]
```
2. Initialize the modules
```bash
terraform init
```
3. Apply while referencing the `.tfvar` file we created
```bash
terraform apply -var-file=your_environment.tfvar
```
## Get kubernetes access
1. Fetch the kubeconfig file by running:
```bash
gcloud container clusters get-credentials $(terraform output -raw gke_cluster_name) --region $(terraform output -raw gke_cluster_location) --project $(terraform output -raw project_id)
```
## Install and configure Kueue
1. Install Kueue by choosing a version and running `kubectl apply` against the manifest availaible on kueue github repo.Note that `--server-side` switch is imporant and command will fail without it.
```bash
VERSION=v0.7.0
kubectl apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/$VERSION/manifests.yaml
```
2. Given that SkyPilot uses pods for provisioning we need to configure Kueue to work with pods. We will achieve this by patching Kueue manager config map. First extract the config and patch
```bash
kubectl -n kueue-system get cm kueue-manager-config -o jsonpath={.data.controller_manager_config\\.yaml} | yq '.integrations.frameworks += ["pod"]' > /tmp/kueueconfig.yaml
```
3. Apply the changes
```bash
kubectl -n kueue-system create cm kueue-manager-config --from_file=controller_manager_config.yaml=/tmp/kueueconfig.yaml --dry-run=client -o yaml | k -n kueue-system apply -f -
```
4. Reset the manager pod
```bash
kubectl -n kueue-system rollout restart deployment kueue-controller-manager
```
5. Wait for completion
```bash
kubectl -n kueue-system rollout status deployment kueue-controller-manager
```
6. Install Kueue resources using the provided `kueue_resources.yaml`.
```bash
kubectl apply -f kueue_resources.yaml
```
Kueue should be up and running now. 

## Install SkyPilot
1. Create a virtual environment.
```bash
cd ~
python -m venv skypilot-test
cd skypilot-test
source bin/activate
```
2. Install SkyPilot
```bash
pip install -U "skypilot[kubernetes]"
```

3. Verify the installation:
```bash
sky check
```
4. Find the context names
```bash
kubectl config get-contexts

# Find the context name, for example: 
gke_${PROJECT_NAME}_us-central1-c_demo-us-central1
```
5. Create a config for SkyPilot at `~/.sky/config.yaml` using the provided context. Make sure to add `autoscaler: gke` as this will allow SkyPilot to run a workload without GPUs provisioned. Also change `PROJECT_NAME` and  `CLUSTER_NAME` to values of the cluster created.
```yaml
allowed_clouds:
  - kubernetes
kubernetes:
  # Use the context's name
  allowed_contexts:
    - gke_${PROJECT_NAME}_europe-west1_${CLUSTER_NAME}
  autoscaler: gke
```
And verify again:
```bash
sky check
```
And you should the the following output
```
  Kubernetes: enabled                              

To enable a cloud, follow the hints above and rerun: sky check
If any problems remain, refer to detailed docs at: https://skypilot.readthedocs.io/en/latest/getting-started/installation.html

Note: The following clouds were disabled because they were not included in allowed_clouds in ~/.sky/config.yaml: GCP, AWS, Azure, Cudo, Fluidstack, IBM, Lambda, OCI, Paperspace, RunPod, SCP, vSphere, Cloudflare (for R2 object store)

🎉 Enabled clouds 🎉
  ✔ Kubernetes
```
## Configure SkyPilot Job
1. For SkyPilot to create pods with the necessary pod config we need to add the following confing to our yaml file. 
```yaml
experimental:
  config_overrides:
    kubernetes:
      pod_config:
        metadata:
          annotations:
            provreq.kueue.x-k8s.io/maxRunDurationSeconds: "3600"
      provision_timeout: 900
```
And labels config to the resources section
```yaml
  labels:
    kueue.x-k8s.io/queue-name: dws-local-queue
```
Refer to the included `train_dws.yaml` file.
## Execute the workload
1. Use `sky launch` command
```bash
sky launch -c skypilot-dws train_dws.yaml
```
SkyPilot will wait in Launching state until the node is provisioned.
```
⚙︎ Launching on Kubernetes.
```
In another terminal you can list pods and it will be in `SchedulingGated` state
```bash
NAME                     READY   STATUS            RESTARTS   AGE
skypilot-dws-00b5-head   0/1     SchedulingGated   0          44s
```
If you describe the `provisioningrequests` resource you can see in the `Conditions:` what is happening with the request. 
```bash
  Conditions:
    Last Transition Time:  2024-12-20T11:40:46Z
    Message:               Provisioning Request was successfully queued.
    Observed Generation:   1
    Reason:                SuccessfullyQueued
    Status:                True
    Type:                  Accepted
    Last Transition Time:  2024-12-20T11:40:47Z
    Message:               Waiting for resources. Currently there are not enough resources available to fulfill the request.
    Observed Generation:   1
    Reason:                ResourcePoolExhausted
    Status:                False
    Type:                  Provisioned
```
When the requested resource is availaible the `provisioningrequest` will reflect that in the `Conditions:`
```bash
    Last Transition Time:  2024-12-20T11:42:55Z
    Message:               Provisioning Request was successfully provisioned.
    Observed Generation:   1
    Reason:                Provisioned
    Status:                True
    Type:                  Provisioned
```
Now the workload will be running
```bash
NAME                     READY   STATUS    RESTARTS   AGE
skypilot-dws-00b5-head   1/1     Running   0          4m49s
```
And later finished
```
✓ Job finished (status: SUCCEEDED).

📋 Useful Commands
Job ID: 1
├── To cancel the job:          sky cancel skypilot-dws 1
├── To stream job logs:         sky logs skypilot-dws 1
└── To view job queue:          sky queue skypilot-dws

Cluster name: skypilot-dws
├── To log into the head VM:    ssh skypilot-dws
├── To submit a job:            sky exec skypilot-dws yaml_file
├── To stop the cluster:        sky stop skypilot-dws
└── To teardown the cluster:    sky down skypilot-dws
```
You can now ssh into the pod, run different workloads and experiment. 

## Cleanup
1. Remove the skypilot cluster:
```
sky down skypilot-dws
```
2. Finally destory the provisioned infrastructure.
```bash
terraform destroy -var-file=your_environment.tfvar
```
