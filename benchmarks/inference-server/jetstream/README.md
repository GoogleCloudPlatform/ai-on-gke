# AI on GKE Benchmarking for JetStream

Deploying and benchmarking JetStream on TPU has many similarities with the standard GPU path. But distinct enough differences to warrant a separate readme. If you are familiar with deploying on GPU, much of this should be familiar. For a more detailed understanding of each step. Refer to our primary benchmarking [README](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/main/benchmarks)

## Pre-requisites
- [kaggle user/token](https://www.kaggle.com/docs/api)
- [huggingface user/token](https://huggingface.co/docs/hub/en/security-tokens)

### Creating K8s infra

To create our TPU cluster, run:

```
# Stage 1 creates the cluster.
cd infra/accelerator-cluster/stage-1

# Copy the sample variables and update the project ID, cluster name and other 
parameters as needed in the `terraform.tfvars` file.
cp sample-tfvars/jetstream-sample.tfvars terraform.tfvars

# Initialize the Terraform modules.
terraform init

# Run plan to see the changes that will be made.
terraform plan

# Run apply if the changes look good by confirming the prompt.
terraform apply
```
To verify that the cluster has been set up correctly, run
```
# Get credentials using fleet membership
gcloud container fleet memberships get-credentials <cluster-name>

# Run a kubectl command to verify
kubectl get nodes
```

## Configure the cluster

To configure the cluster to run inference workloads we need to set up workload identity and GCS Fuse.
```
# Stage 2 configures the cluster for running inference workloads.
cd infra/stage-2

# Copy the sample variables and update the project number and cluster name in
# the fleet_host variable "https://connectgateway.googleapis.com/v1/projects/<project-number>/locations/global/gkeMemberships/<cluster-name>"
# and the project name and bucket name parameters as needed in the
# `terraform.tfvars` file. You can specify a new bucket name in which case it
# will be created.
cp sample-tfvars/jetstream-sample.tfvars terraform.tfvars

# Initialize the Terraform modules.
terraform init

# Run plan to see the changes that will be made.
terraform plan

# Run apply if the changes look good by confirming the prompt.
terraform apply
```

### Convert Gemma model weights to maxtext weights

JetStream has [two engine implementations](https://github.com/google/JetStream?tab=readme-ov-file#jetstream-engine-implementation). A Jax variant (via MaxText) and a Pytorch variant. This guide will use the Jax backend.

Jetstream currently requires that models be converted to MaxText weights. This example will deploy a Gemma-7b model. Much of this information is similar to this guide [here](https://cloud.google.com/kubernetes-engine/docs/tutorials/serve-gemma-tpu-jetstream#convert-checkpoints).

*SKIP IF ALREADY COMPLETED*

Create kaggle secret
```
kubectl create secret generic kaggle-secret \
    --from-file=kaggle.json
```

Replace `model-conversion/kaggle_converter.yaml: GEMMA_BUCKET_NAME` with the correct bucket name where you would like the model to be stored.
***NOTE: If you are using a different bucket that the ones you created give the service account Storage Admin permissions on that bucket. This can be done on the UI or by running:
```
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member "serviceAccount:SA_NAME@PROJECT_ID.iam.gserviceaccount.com" \
    --role roles/storage.admin
```

Run:
```
kubectl apply -f model-conversion/kaggle_converter.yaml
```

This should take ~10 minutes to complete.

### Deploy JetStream

Replace the `jetstream.yaml:GEMMA_BUCKET_NAME` with the same bucket name as above.

Run:
```
kubectl apply -f jetstream.yaml
```

Verify the pod is running with
```
kubectl get pods
```

Get the external IP with:

```
kubectl get services
```

And you can make a request prompt with:
```
curl --request POST \
--header "Content-type: application/json" \
-s \
JETSTREAM_EXTERNAL_IP:8000/generate \
--data \
'{
    "prompt": "What is a TPU?",
    "max_tokens": 200
}'
```

### Deploy the benchmark

To prepare the dataset for the Locust inference benchmark, view the README.md file in:
```
cd benchmark/dataset/ShareGPT_v3_unflitered_cleaned_split
```

To deploy the Locust inference benchmark with the above model, run
```
cd benchmark/tools/locust-load-inference

# Copy the sample variables and update the project number and cluster name in
# the fleet_host variable "https://connectgateway.googleapis.com/v1/projects/<project-number>/locations/global/gkeMemberships/<cluster-name>"
# in the `terraform.tfvars` file.
cp sample-tfvars/jetstream-sample.tfvars terraform.tfvars

# Initialize the Terraform modules.
terraform init

# Run plan to see the changes that will be made.
terraform plan

# Run apply if the changes look good by confirming the prompt.
terraform apply
```

To further interact with the Locust inference benchmark, view the README.md file in `benchmark/tools/locust-load-inference`
