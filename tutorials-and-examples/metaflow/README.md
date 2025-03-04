# Fine-Tuning Gemma 2-9B on GKE using Metaflow

This tutorial will provide instructions on how to deploy and use the [Metaflow](https://docs.metaflow.org/) framework on GKE (Google Kubernetes Engine) and operate AI/ML workloads using [Argo-Workflows](https://argo-workflows.readthedocs.io/en/latest/). 

# Overview

This tutorial is designed for ML Platform engineers who plan to use Metaflow for ML workloads on top of GKE by offloading resource-intensive tasks to a managed cluster.

## What will you learn

1. Provision required infrastructure automatically (using Terraform). The GKE Autopilot cluster is used by default.  
2. Install [Argo Workflows](https://argoproj.github.io/workflows/) on GKE cluster  
3. Install and configure Metaflow to work with Argo Workflows on GKE cluster  
4. Fine-tune `gemma-2-9b` model and serve the resulting model from the GKE cluster.  
5. Install Metaflow’s Metadata Service on the GKE cluster (Optional but Recommended) – enable remote metadata storage to replace on local storage. While not required, this setup can enhance collaboration and teamwork by providing a centralized metadata repository. [Learn more here.](https://docs.metaflow.org/getting-started/infrastructure). 

## Filesystem structure

* `finetune_inside_metaflow/` \- folder with [Metaflow Flow](https://docs.metaflow.org/metaflow/basics) for fine-tuning the Gemma-2 model.  
* `serve_model/` \- a simple deployment manifest for serving the fine-tuned model within the same GKE cluster.  
* `templates/` \- folder with Kubernetes manifests that require additional processing to specify additional values that are not known from the start.   
* `terraform/` \- folder with terraform config that executes automated provisioning of required infrastructure resources.

# Before you begin

1. Ensure you have a gcp project with billing enabled and [enabled the GKE API](https://cloud.google.com/kubernetes-engine/docs/how-to/enable-gkee).  
2. Ensure you have the following tools installed on your workstation

    * [gcloud CLI](https://cloud.google.com/sdk/docs/install)  
    * [gcloud kubectl](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_kubectl)  
    * [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)  
    * [python](https://docs.python.org/3/using/index.html)  
    * [venv](https://packaging.python.org/en/latest/guides/installing-using-pip-and-virtual-environments/)

If you previously installed the gcloud CLI, get the latest version by running:

```
gcloud components update
```

 Ensure that you are signed in using the gcloud CLI tool. Run the following command:

```
gcloud auth application-default login
```

# Infrastructure Setup

## Create cluster and other resources

In this section we will use `Terraform` to automate the creation of infrastructure resources. For more details how it is done please refer to the terraform config in the `terraform/` folder.
By default, the configuration provisions an Autopilot GKE cluster, but it can be changed to standard by setting `autopilot_cluster = false`.

It creates:

* Cluster IAM Service Account – manages permissions for the GKE cluster.
* Metaflow Metadata Service IAM Service Account – grants Kubernetes permissions for Metaflow’s metadata service using [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
* Argo Workflows IAM Service Account – grants Kubernetes permissions for Argo Workflows using [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
* [CloudSQL](https://cloud.google.com/sql/docs/introduction) instance for Metaflow metadata database  
* GCS bucket for Metaflow’s artifact storage  
* [Artifact registry](https://cloud.google.com/artifact-registry/docs/overview) – stores container images for the fine-tuning process.



1. Go the the terraform directory:

```
cd terraform
```

2. Specify the following values inside the `default_env.tfvars` file (or make a separate copy):  
        
    - `<PROJECT_ID>` – replace with your project id (you can find it in the project settings).


Other values can be changed, if needed, but can be left with default values.

3. (Optional) For better state management and collaboration, you can configure Terraform to store its state in a GCS bucket instead of keeping it locally.  [Create a bucket](https://cloud.google.com/storage/docs/creating-buckets#command-line) manually and then uncomment the content of the file `terraform/backend.tf` and specify your bucket:

```
terraform {
   backend "gcs" {
     bucket = "<bucket_name>"
     prefix = "terraform/state/metaflow"
   }
 }
```

4. Init terraform modules:

```
terraform init
```

 
5. Optionally run the `plan` command to view an execution plan: 

```
terraform plan -var-file=default_env.tfvars
```

6. Execute the plan:

```
terraform apply -var-file=default_env.tfvars
```

And you should see your resources created:

```
Apply complete! Resources: 106 added, 0 changed, 0 destroyed.

Outputs:

argo_workflows_k8s_sa_name = "metaflow-tutorial-argo-sa"
cloudsql_instance_name = "metaflow-tutorial-tf"
finetune_image_registry_name = "metaflow-tutorial-tf"
gke_cluster_location = "us-central1"
gke_cluster_name = "metaflow-tutorial-tf"
metaflow_datastore_bucket_name = "metaflow-tutorial-tf"
metaflow_k8s_namespace = "default"
metaflow_k8s_sa_name = "metaflow-tutorial-sa"
project_id = "akvelon-gke-aieco"

```

7. Configure your kubectl context:

```
gcloud container clusters get-credentials $(terraform output -raw gke_cluster_name) --region $(terraform output -raw gke_cluster_location) --project $(terraform output -raw project_id)
```

# Metaflow Configuration

## Deploy Metadata Service

This tutorial includes two Kubernetes manifests for Metaflow Metadata service:

- [*Metadata-service*](https://github.com/Netflix/metaflow-service) \- Keeps track of metadata.   
- [*UI-service*](https://github.com/Netflix/metaflow-service/tree/master/services/ui_backend_service) \- Provides a backend instance that powers a web interface for monitoring active flows.

The manifests are generated from templates in the `templates` directory and put in the `gen` directory.

1. Apply metadata service manifest:

```
kubectl apply -f ../gen/metaflow-metadata.yaml
```

2. Wait for deployment is completed:

```
kubectl rollout status deployment/metaflow-metadata
```

3. Apply UI service manifest:

```
kubectl apply -f ../gen/metaflow-ui.yaml
```

4. Wait for deployment is completed:

```
kubectl rollout status deployment/metaflow-ui
```

5. Open new terminal and forward the metadata service port. Keep this terminal running to ensure connection to a remote metadata service:

```
kubectl port-forward svc/metaflow-metadata-svc 8080:8080
```

6. Open new terminal and forward port for UI. Keep this terminal running to ensure connection to a Metaflow UI service:

```
kubectl port-forward svc/metaflow-ui-svc 8083:8083
```

7. Open  [http://localhost:8083/](http://localhost:8083/). Now all new submitted Metaflow runs will be shown here. 

      

## Install and configure Metaflow locally

1. Create a Python virtual environment, activate it and install Metaflow and other requirements.

```
python3 -m venv ../venv
. ../venv/bin/activate
python3 -m pip install metaflow google-cloud-storage google-auth kubernetes==31.0.0
```

2. Create metaflow’s config folder, if not present:

```
mkdir -p ~/.metaflowconfig
```

3. Create Metaflow config. Some of the missing values we get from the terraform output.


```
cat <<EOF > ~/.metaflowconfig/config.json
{
"METAFLOW_DEFAULT_METADATA": "service",
"METAFLOW_SERVICE_URL": "http://localhost:8080",
"METAFLOW_SERVICE_INTERNAL_URL": "http://metaflow-metadata-svc.default:8080/",
"METAFLOW_DEFAULT_DATASTORE": "gs",
"METAFLOW_DATASTORE_SYSROOT_GS": "gs://$(terraform output -raw metaflow_datastore_bucket_name)",
"METAFLOW_KUBERNETES_NAMESPACE": "argo",
"METAFLOW_KUBERNETES_SERVICE_ACCOUNT": "$(terraform output -raw argo_workflows_k8s_sa_name)",
"METAFLOW_KUBERNETES_DISK": 2048
}
EOF
```

More on Metaflow configuration values:

| Name | Description |
| :---- | :---- |
| METAFLOW\_DEFAULT\_METADATA | With the `service` option, it communicates with the metadata service that has been deployed. |
| METAFLOW\_SERVICE\_URL | URL for your Metaflow CLI to communicate with the metadata backend. |
| METAFLOW\_SERVICE\_INTERNAL\_URL | Internal URL for the same  metadata backend.  |
| METAFLOW\_DEFAULT\_DATASTORE | Specifies the type of storage where metaflow will store artifacts of its runs. In our case it is a GCS bucket.  |
| METAFLOW\_DATASTORE\_SYSROOT\_GS | GCS bucket name to store artifacts produced by metaflow runs.  |
| METAFLOW\_KUBERNETES\_NAMESPACE | Namespace in the cluster for metaflow runs. In our case it is `argo` |
| METAFLOW\_KUBERNETES\_SERVICE\_ACCOUNT | Service account which is assigned to pods with Metaflow runs. |
| METAFLOW\_KUBERNETES\_DISK | Sets disk size for a container for metaflow run. The default value of this option is too big for Autopilot GKE cluster, so we decrease it to 2048 |


## Build the fine-tuning container image

The model fine-tuning process requires a dedicated environment, which we will encapsulate in a container image. The dockerfile can be found in `finetune_inside_metaflow/image/Dockerfile`. 

1. Build the image using [Cloud Build](https://cloud.google.com/build/docs/overview) and push it to the newly created repository. That may take some time:

```
gcloud builds submit ../finetune_inside_metaflow/image \
    --substitutions="_IMAGE_REGISTRY_NAME=$(terraform output -raw finetune_image_registry_name)" \
    --config=../cloudbuild.yaml
```

*More details can be found in the `cloudbuild.yaml` file.*

2. Create [config file](https://docs.metaflow.org/metaflow/configuring-flows/basic-configuration) that specifies previously built image to be used in the finetuning flow:  
   

```
cat <<EOF > ../finetune_flow_config.json
{
"image_name":"us-docker.pkg.dev/$(terraform output -raw project_id)/$(terraform output -raw finetune_image_registry_name)/finetune:latest",
"new_model": "finetunned-gemma2-9b"
}
EOF
```

	  
Here:

* `image_name` : image that was previously built and pushed to our registry  
* `new_model:`  Name of a resulting model.

# Model Fine-tuning and Serving 

## Fine-tune the model

1. Specify your [HuggingFace token](https://huggingface.co/settings/tokens). It will be used to access model that we want to finetune:

```
HF_TOKEN="<your_token>"
```

2. Specify your HuggingFase user

```
HF_USERNAME="<your_username>"
```

3. Create secret with your token to HuggingFace:

```
kubectl -n argo create secret generic hf-token --from-literal=HF_TOKEN=${HF_TOKEN}
```

4. Create argo-workflows template from the metaflow fintuning script:

```
python3 ../finetune_inside_metaflow/finetune_gemma.py \
--config config ../finetune_flow_config.json \
argo-workflows create
```

We specify previously created config file `finetune_flow_config.json` by using the `--config` option.

<details>

<summary> More details on the flow class :</summary>


```
class FinetuneFlow(FlowSpec):

    # config file has to specify image name 
    finetune_flow_config = Config("config", default="flow_config.json")

    # specify environment variables required by the finetune process
    @environment(vars={
        # model to finetune
        "MODEL_NAME": "google/gemma-2-9b", 
        "LORA_R": "8",
        "LORA_ALPHA": "16",
        "TRAIN_BATCH_SIZE": "1",
        "EVAL_BATCH_SIZE": "2",
        "GRADIENT_ACCUMULATION_STEPS": "2",
        "DATASET_LIMIT": "1000",
        "MAX_SEQ_LENGTH": "512",
        "LOGGING_STEPS": "5",
    })

    # specify kubernetes-specific options 
    @kubernetes(
        image=finetune_flow_config.image_name,
        image_pull_policy="Always",
        cpu=2,
        memory=1024,
        # secret to huggingfase that has to be added as a Kubernetes secret
        secrets=["hf-token"],
        # specify required GPU settings
        gpu=1,
        node_selector={"cloud.google.com/gke-accelerator": "nvidia-tesla-a100"}
    )
    @retry
    @step
    def start(self):
        print("Start finetuning")
        import finetune
        finetune.finetune_and_upload_to_hf(new_model=self.finetune_flow_config.new_model)
        self.next(self.end)

    @step
    def end(self):
        print("FinetuneFlow is finished.")

```
</details>


5. Open new terminal and forward port for argo-workflows server. Keep this terminal running to ensure uninterrupted access to the argo-workflows UI.

```
kubectl -n argo port-forward svc/argo-server 2746:2746
```

6. Open argo-workflows UI at [https://localhost:2746](https://localhost:2746) and go to the [workflow templates](https://localhost:2746/workflow-templates) section. There must be a template that you have created earlier.

![argo-workflows-templates](https://github.com/user-attachments/assets/dff16d8f-d41d-4b4f-8cb4-ec018d8630ff)


7. Select this template and click submit to start the workflow:

![argo-workflows-submit](https://github.com/user-attachments/assets/476cc157-3410-4987-9d27-725f79c531a1)


Wait until the fine-tuning process is completed and a new model is uploaded to the HuggingFace. It should take around 30 minutes to complete.

Note: There may be temporary warnings about insufficient cluster resources, but they should be eventually resolved in a few minutes.

You can open the Metaflow UI at http://localhost:8083/ to monitor the execution details of your Metaflow flows.

Note: this UI does not display the model upload status to HuggingFace

![metaflow-ui](https://github.com/user-attachments/assets/0e1b9a91-5175-4237-a777-94866170a7c2)

8. Go to your [Hugging Face](https://huggingface.co/) profile to verify that the fine-tuned model has been uploaded:

![huggingface](https://github.com/user-attachments/assets/b67d0632-a12b-4195-b651-62181256ac5e)



## Serve the Fine-Tuned Model on GKE

1. Replace the placeholder for your HuggingFace handle and run this command. 

```
kubectl create configmap vllm-config --from-literal=model_id="${HF_USERNAME}/finetunned-gemma2-9b"
```

2. Create secret with your token to HuggingFace:

```
kubectl create secret generic hf-token --from-literal=HF_TOKEN=${HF_TOKEN}
```

3. Deploy the resulting model to GKE. This will deploy the inference server and it will serve a previously finetuned model. The deployment `serve_model/vllm_deplyment.yaml`  is based on this [instruction](https://cloud.google.com/kubernetes-engine/docs/tutorials/serve-gemma-gpu-vllm#gemma-2-9b-it)


```
kubectl apply -f serve_model/vllm_deplyment.yaml
```

4. Wait for deployment is completed. It may take some time:

```
kubectl rollout status deployment/vllm-gemma-deployment
```

5. Open another terminal and forward port for of the inference server:

```
kubectl port-forward svc/llm-service 8000:8000
```

6. Interact with the model

```

USER_PROMPT="Question: What is the total number of attendees with age over 30 at kubecon \\\"EU\\\"? Context: CREATE TABLE attendees (name VARCHAR, age INTEGER, kubecon VARCHAR)\nAnswer:"

curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
    "prompt": "${USER_PROMPT}",
    "temperature": 0.90,
    "top_p": 1.0,
    "max_tokens": 32
}
EOF
```

The output should look like this:

```
{"predictions":["Prompt:\nQuestion: What is the total number of attendees with age over 30 at kubecon \"EU\"? Context: CREATE TABLE attendees (name VARCHAR, age INTEGER, kubecon VARCHAR)\nAnswer:\nOutput:\n SELECT COUNT(name) FROM attendees WHERE age > 30 AND kubecon = \"EU\"\nContext: CREATE TABLE attendees (name VARCHAR, age INTEGER"]}
```

## Cleanup

1. Destroy the provisioned infrastructure.

```
cd terraform 
terraform destroy -var-file=default_env.tfvars
rm -rf .venv finetune_flow_config.json 
```

2. Remove created files:

```
rm -rf .venv finetune_flow_config.json
```

## Troubleshooting

* In case of usage of this guide by multiple people at the same time, consider renaming resource names in the `default_env.tfvars` to avoid name collisions.  
* Some operations over the autopilot cluster can hang and complete once the initial scale-up event has finished.  
* Sometimes access to the network through `kubectl port-forward` stops working and restarting the command can solve the problem.
