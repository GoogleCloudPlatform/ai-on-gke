# Efficient GPU Resource Management for ML Workloads using SkyPilot, Kueue on GKE

This tutorial expands on the [SkyPilot Tutorial](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/main/tutorials-and-examples/skypilot) by leveraging [Dynamic Workload Scheduler](https://cloud.google.com/blog/products/compute/introducing-dynamic-workload-scheduler) with the help of an open-source project called [Kueue](https://kueue.sigs.k8s.io/)
Different from the SkyPilot tutorial, this guide shows how to use SkyPilot with Kueue on GKE to efficiently manage ML workloads with dynamic GPU provisioning.

## Overview
This tutorial is designed for ML Platform engineers who plan to use SkyPilot to train or serve LLM models on Google Kubernetes Engine (GKE) while utilizing Dynamic Workload Scheduler (DWS) to acquire GPU resources as they become available. It covers installing Kueue and Skypilot, creating a GKE cluster with queue processing enabled GPU node pools, and deploying and running a LLM model. This setup enhances resource efficiency and reduces cost for ML workloads through dynamic GPU provisioning.

## Before you begin
1. Ensure you have a gcp project with billing enabled and the GKE API activated.
Learn how to [enable billing](https://cloud.google.com/billing/v1/getting-started) and activate the GKE API.
You can use `gcloud` cli to activate GKE API.
```
gcloud services enable container.googleapis.com
```

2. Ensure you have the following tools installed on your workstation
* [gcloud CLI](https://cloud.google.com/sdk/docs/install)
* [gcloud kubectl](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_kubectl)
* [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
* [python](https://docs.python.org/3/using/index.html)
* [venv](https://packaging.python.org/en/latest/guides/installing-using-pip-and-virtual-environments/)
* [yq](https://github.com/mikefarah/yq/#install)

## Setting up your GKE cluster with Terraform
We’ll use Terraform to provision:
- A GKE cluster ([Autopilot](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview) or [Standard](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-regional-cluster))
- GPU node pools (only for Standard clusters)

1. Create your environment configuration(.tfvar) file and edit based on  example_environment.tfvars. 
```
project_id = "skypilot-project"
cluster_name = "skypilot-tutorial"
autopilot_cluster = true  # Set to false for Standard cluster
```
2. (Optional) For Standard clusters: Configure GPU node pools in example_environment.tfvars by uncommenting and adjusting the gpu_pools block as needed. 
```
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
## Deployment
1. Initialize the modules
```bash
terraform init
```
2. Apply while referencing the `.tfvar` file we created
```bash
terraform apply -var-file=your_environment.tfvar
```
And you should see your resources created:
```
Apply complete! Resources: 24 added, 0 changed, 0 destroyed.

Outputs:

gke_cluster_location = "us-central1"
gke_cluster_name = "skypilot-tutorial"
kubernetes_namespace = "ai-on-gke"
project_id = "skypilot-project"
service_account = "tf-gke-skypilot-tutorial@skypilot-project.iam.gserviceaccount.com"
```
3. Get kubernetes access
```bash
gcloud container clusters get-credentials $(terraform output -raw gke_cluster_name) --region $(terraform output -raw gke_cluster_location) --project $(terraform output -raw project_id)
```
4. Verify your GKE cluster's version, run:
```
kubectl version
```
Make sure you meet the minimum version requirements (1.30.3-gke.1451000 or later for Autopilot, 1.28.3-gke.1098000 or later for Standard)
```
Server Version: v1.30.6-gke.1596000
```
If not, you can change the version in Terraform with the  `kubectl_version` variable
## Install and configure Kueue
1. Install Kueue from the official manifest.\
Note that `--server-side` switch . Without it the client cannot render the CRDs because of annotation size limitations.
```bash
VERSION=v0.7.0
kubectl apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/$VERSION/manifests.yaml
```
2. Configure Kueue for pod provisioning by patching the Kueue configmap.
```bash
# Extract and patch the config
# This is required because SkyPilot creates and manages workloads as pods
kubectl -n kueue-system get cm kueue-manager-config -o jsonpath={.data.controller_manager_config\\.yaml} | yq '.integrations.frameworks += ["pod"]' > /tmp/kueueconfig.yaml
```
3. Apply the changes
```bash
kubectl -n kueue-system create cm kueue-manager-config --from_file=controller_manager_config.yaml=/tmp/kueueconfig.yaml --dry-run=client -o yaml | kubectl -n kueue-system apply -f -
```
4. Restart the kueue-controller-manager pod with the following command
```bash
kubectl -n kueue-system rollout restart deployment kueue-controller-manager
# Wait for the restart to complete
kubectl -n kueue-system rollout status deployment kueue-controller-manager
```
5. Install Kueue resources using the provided `kueue_resources.yaml`.
```bash
kubectl apply -f kueue_resources.yaml
```
Kueue should be up and running now. 

## Install SkyPilot
1. Create a python virtual environment.
```bash
cd ~
python -m venv skypilot-test
cd skypilot-test
source bin/activate
```
2. Install SkyPilot
```bash
pip install -U "skypilot[kubernetes]"
# Verify the installation
sky -v
```
3. Find the context names
```bash
kubectl config get-contexts

# Find the context name, for example: 
# gke_${PROJECT_NAME}_us-central1-c_demo-us-central1

```
Create SkyPilot configuration. Add `autoscaler: gke` to enable SkyPilot to work with GKE's cluster autoscaling capabilities, allowing you to run workloads without pre-provisioned GPU nodes.
```
# Create and edit ~/.sky/config.yaml
# Change PROJECT_NAME, LOCATION and CLUSTER_NAME
allowed_clouds:
  - kubernetes
kubernetes:
  # Use the context's name
  allowed_contexts:
    - gke_${PROJECT_NAME}_europe-${LOCATION}_${CLUSTER_NAME}
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
## Configure and Run SkyPilot Job
For SkyPilot to create pods with the necessary pod config we need to add the following config to `train_dws.yaml`.
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
Launch the workload
```bash
sky launch -c skypilot-dws train_dws.yaml
```
SkyPilot will wait in Launching state until the node is provisioned.
```
⚙︎ Launching on Kubernetes.
```
In another terminal, you can `kubectl get pods` and it will be in SchedulingGated state
```bash
NAME                     READY   STATUS            RESTARTS   AGE
skypilot-dws-00b5-head   0/1     SchedulingGated   0          44s
```
If you run `kubectl describe provisioningrequests` you can see in the Conditions: what is happening with the request.
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

## Fine-tune and Serve Gemma 2B on GKE
This section details how to fine-tune Gemma 2B for SQL generation on GKE Autopilot using SkyPilot. Model artifacts stored in Google Cloud Storage (GCS) bucket and shared across pods using [gcsfuse](https://cloud.google.com/storage/docs/cloud-storage-fuse/overview). The workflow separates training and serving into distinct pods, managed through [finetune.yaml](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/skypilot_dws_kueue/tutorials-and-examples/skypilot/dws-and-kueue/finetune.yaml) and [serve.yaml](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/skypilot_dws_kueue/tutorials-and-examples/skypilot/dws-and-kueue/serve.yaml).  We'll use two SkyPilot commands for this workflow:
 - `sky launch`: For running the fine-tuning job 
 - `sky serve`: For deploying the model as a persistent service


### Prerequisites
 - A GKE cluster configured with SkyPilot
 - HuggingFace account with access to Gemma model

### Fine-tuning Implementation
The [finetune.py](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/skypilot_dws_kueue/tutorials-and-examples/skypilot/dws-and-kueue/code/finetune.py) script uses QLoRA with 4-bit quantization to fine-tune Gemma 2B on SQL generation tasks.

### Configure GCS Storage Access
The infrastructure Terraform configuration in [main.tf](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/skypilot_dws_kueue/tutorials-and-examples/skypilot/dws-and-kueue/main.tf) includes Workload Identity and GCS bucket setup:
```
module "skypilot-workload-identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  name                = "skypilot-service-account"
  namespace           = "default"
  project_id          = var.project_id
  roles               = ["roles/storage.admin", "roles/compute.admin"]
  cluster_name = module.infra[0].cluster_name
  location = var.cluster_location
  use_existing_gcp_sa = true
  gcp_sa_name = data.google_service_account.gke_service_account.email
  use_existing_k8s_sa = true
  annotate_k8s_sa = false
}

```
1. Get project and service account details
```
terraform output project_id
terraform output service_account
```
2. Configure Workload Identity\
Run additional commands to connect the Google Cloud Service Account that was created with Terraform with Identity Federation enabled to be able to use gcsfuse.
```
gcloud iam service-accounts add-iam-policy-binding SERVICE_ACCOUNT \
          --role roles/iam.workloadIdentityUser \
          --member "serviceAccount:PROJECT_ID.svc.id.goog[default/skypilot-service-account]"
```
This will create policy binding that will allow the kubernetes service account to impersonate the google service account. Also note that  `[default/skypilot-service-account]` is the kubernetes namespace and service account name that is deployed by SkyPilot by default. Change if you specifically changed SkyPilot configuration or used another namespace. 
3. Annotate Kubernetes service account
```
kubectl annotate serviceaccount skypilot-service-account --namespace default iam.gke.io/gcp-service-account=SERVICE_ACCOUNT
```
4. Get the bucket name
```
terraform output model_bucket_name
```
5. Update gcsfuse configuration in `finetune.yaml` and `serve.yaml`\
Replace the [BUCKET_NAME](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/skypilot_dws_kueue/tutorials-and-examples/skypilot/dws-and-kueue/finetune.yaml#L27)

### Fine-tune the Model
1. Set up HuggingFace access:
Finetune script needs a HuggingFace token and to sign the licence consent agreement.\
Follow instructions on the following link: [Get access to the model](https://cloud.google.com/kubernetes-engine/docs/tutorials/serve-gemma-gpu-vllm#model-access)
```
export HF_TOKEN=tokenvalue
```
2. Launch a fine-tuning job:
```
sky launch -c finetune finetune.yaml --retry-until-up --env HF_TOKEN=$HF_TOKEN
```
After finetuning is finished you should see the following output
```
(gemma-finetune, pid=1837) 
100%|██████████| 5000/5000 [12:49<00:00,  6.50it/s]00 [12:49<00:00,  6.81it/s]
(gemma-finetune, pid=1837) /home/sky/miniconda3/lib/python3.10/site-packages/huggingface_hub/file_download.py:795: FutureWarning: `resume_download` is deprecated and will be removed in version 1.0.0. Downloads always resume when possible. If you want to force a new download, use `force_download=True`.
(gemma-finetune, pid=1837)   warnings.warn(
(gemma-finetune, pid=1837) 
(gemma-finetune, pid=1837) Loading checkpoint shards:   0%|          | 0/2 [00:00<?, ?it/s]
Loading checkpoint shards: 100%|██████████| 2/2 [00:07<00:00,  3.93s/it]/2 [00:07<00:07,  7.61s/it]
✓ Job finished (status: SUCCEEDED).
```

### Serve the Model
Next, run the finetuned model with the `serve.yaml` and serve cli
```
sky serve up serve.yaml
```
When the serve pods are provisioned you should see the following output
```
⚙︎ Launching serve controller on Kubernetes.
└── Pod is up.
✓ Cluster launched: sky-serve-controller-00b550a3.  View logs at: ~/sky_logs/sky-2025-01-08-19-25-40-242969/provision.log
⚙︎ Mounting files.
  Syncing (to 1 node): /tmp/service-task-sky-service-7e46-jyxqvkgh -> ~/.sky/serve/sky_service_7e46/task.yaml.tmp
  Syncing (to 1 node): /tmp/tmpd_sj9qpw -> ~/.sky/serve/sky_service_7e46/config.yaml
✓ Files synced.  View logs at: ~/sky_logs/sky-2025-01-08-19-25-40-242969/file_mounts.log
⚙︎ Running setup on serve controller.
  Check & install cloud dependencies on controller: done.                                        
✓ Setup completed.  View logs at: ~/sky_logs/sky-2025-01-08-19-25-40-242969/setup-*.log
⚙︎ Service registered.

Service name: sky-service-7e46
Endpoint URL: 35.226.190.154:30002
📋 Useful Commands
├── To check service status:    sky serve status sky-service-7e46 [--endpoint]
├── To teardown the service:    sky serve down sky-service-7e46
├── To see replica logs:        sky serve logs sky-service-7e46 [REPLICA_ID]
├── To see load balancer logs:  sky serve logs --load-balancer sky-service-7e46
├── To see controller logs:     sky serve logs --controller sky-service-7e46
├── To monitor the status:      watch -n10 sky serve status sky-service-7e46
└── To send a test request:     curl 35.226.190.154:30002

✓ Service is spinning up and replicas will be ready shortly.
```
Check if the serving api is ready by running 
```
sky status
```
And wait for the `PROVISIONING` status to appear `READY`
```
Services
NAME              VERSION  UPTIME   STATUS      REPLICAS  ENDPOINT              
sky-service-7e46  -        -        NO_REPLICA  0/1       35.226.190.154:30002  


Service Replicas
SERVICE_NAME      ID  VERSION  ENDPOINT                  LAUNCHED     RESOURCES                   STATUS        REGION                                                   
sky-service-7e46  1   1        -                         1 min ago    1x Kubernetes({'A100': 1})  PROVISIONING  gke_skypilot_project_us-central1_-skypilot-test  
```
After that take the url from the `ENDPOINT` and use curl to prompt the served model
```
curl -X POST http://SKYPILOT_ADDRESS/generate \
       -H "Content-Type: application/json" \
       -d '{ "prompt": "Question: What is the total number of attendees with age over 30 at kubecon eu? Context: CREATE TABLE attendees (name VARCHAR, age INTEGER, kubecon VARCHAR) Answer:","top_p": 1.0, "temperature": 0 , "max_tokens":128 }' \
       | jq
```
And you should see the reply
```
Answer: SELECT COUNT(name) FROM attendees WHERE age > 30 AND kubecon = \"kubecon eu\"\
```

## Cleanup
1. Remove the skypilot cluster and serve endpoints:
```
sky down skypilot-dws
sky down test-finetune
sky serve down --all
```
2. Finally destory the provisioned infrastructure.
```bash
terraform destroy -var-file=your_environment.tfvar
```
## Troubleshooting

1. If Kueue install gives the error:
```
the CustomResourceDefinition "workloads.kueue.x-k8s.io" is invalid: metadata.annotations: Too long: must have at most 262144 bytes
```
Make sure you include the `--server-side` argument to the `kubectl apply` command when installing Kueue. Delete it first if repeating the step

2. If you get an error with the kueue-webhook-service.
```
Error from server (InternalError): error when creating "kueue_resources.yaml": Internal error occurred: failed calling webhook "mresourceflavor.kb.io": failed to call webhook: Post "https://kueue-webhook-service.kueue-system.svc:443/mutate-kueue-x-k8s-io-v1beta1-resourceflavor?timeout=10s": no endpoints available for service "kueue-webhook-service"
```
Wait for endpoints for the kueue-webhook-service to be populated with the kubectl wait command
```
kubectl -n kueue-system wait endpoints/kueue-webhook-service --for=jsonpath={.subsets}
```

3. If SkyPilot refuses to start the cluster because there is no nodes that would satify the requirement for GPU
```
Task from YAML spec: train_dws.yaml
No resource satisfying Kubernetes({'L4': 1}) on Kubernetes.
sky.exceptions.ResourcesUnavailableError: Kubernetes cluster does not contain any instances satisfying the request: 1x Kubernetes({'L4': 1}).
To fix: relax or change the resource requirements.

Hint: sky show-gpus to list available accelerators.
      sky check to check the enabled clouds.
```
Make sure you added `autoscaling: gke` to the sky config in step [Install SkyPilot](#install-skypilot)

4. Permission denied when trying to write to the mounted gcsfuse volume.

Make sure you added `uid=1000,gid=1000` to the `mountOptions:` YAML inside of the task yaml file. SkyPilot by default uses 1000 gid and uid
```
volumes:
  - name: gcsfuse-test
    csi:
      driver: gcsfuse.csi.storage.gke.io
      volumeAttributes:
        bucketName: MODEL_BUCKET_NAME
        mountOptions: "implicit-dirs,uid=1000,gid=1000"
```
5. Denied by autogke-gpu-limitation

When running `sky serve` on Autopilot cluster GKE Warden rejects the pods

```
"kind":"Status","apiVersion":"v1","metadata":{},"status":"Failure","message":"admission webhook \"warden-validating.common-webhooks.networking.gke.io\" denied the request: GKE Warden rejected the request because it violates one or more constraints.\nViolations details: {\"[denied by autogke-gpu-limitation]\":[\"The toleration with key 'nvidia.com/gpu' and operator 'Exists' cannot be specified if the pod does not request to use GPU in Autopilot.\"
```
Update SkyPilot to version 0.8.0 and above. 

[More Details](https://github.com/skypilot-org/skypilot/issues/4542)