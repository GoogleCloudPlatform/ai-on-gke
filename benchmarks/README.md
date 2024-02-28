# AI on GKE Benchmarking

This framework enables you to run automated benchmarks on GKE for AI workloads via Terraform automation.
You can find the current set of supported cluster deployments under `infra/` and the supported inference servers
under `inference-server/`.

Note that you can run any stage separate from another. For example, you can deploy your own inference server
on a cluster created via these terraform scripts. And vice versa, you can deploy the inference servers
via these terraform scripts on a Standard cluster that you've created yourself.

## Pre-requisites

### Terraform

Install Terraform by following the documentation at https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli.
This requires a minimum Terraform version of 1.7.4

## Deploy and serve an ML model

This section goes over an end to end example to deploy and serve the Falcon 7b model using (TGI)[https://huggingface.co/docs/text-generation-inference/en/index] on a Standard GKE Cluster with GPUs.

Each step below has more details in their respective directoy README.md. It is recommended
that you read through the available options at least once when testing your own models.

### Create the cluster

Set up the infrastructure by creating a GKE cluster with appropriate accelerator
configuration.

To create a GPU cluster, run
```
# Stage 1 creates the cluster.
cd infra/stage-1

# Copy the sample variables and update the project ID, cluster name and other
parameters as needed in the `terraform.tfvars` file.
cp sample-terraform.tfvars terraform.tfvars

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

### Configure the cluster

To configure the cluster to run inference workloads we need to set up workload
identity, GCS Fuse and DCGM for GPU metrics.
```
# Stage 2 configures the cluster for running inference workloads.
cd infra/stage-2

# Copy the sample variables and update the project number and cluster name in
# the fleet_host variable "https://connectgateway.googleapis.com/v1/projects/<project-number>/locations/global/gkeMemberships/<cluster-name>"
# and the project name and bucket name parameters as needed in the
# `terraform.tfvars` file. You can specify a new bucket name in which case it
# will be created.
cp sample-terraform.tfvars terraform.tfvars

# Initialize the Terraform modules.
terraform init

# Run plan to see the changes that will be made.
terraform plan

# Run apply if the changes look good by confirming the prompt.
terraform apply
```

### Deploy the inference server

To deploy TGI with a sample model, run
```
cd inference-server/text-generation-inference

# Copy the sample variables and update the project number and cluster name in
# the fleet_host variable "https://connectgateway.googleapis.com/v1/projects/<project-number>/locations/global/gkeMemberships/<cluster-name>"
# in the `terraform.tfvars` file.
cp sample-terraform.tfvars terraform.tfvars

# Initialize the Terraform modules.
terraform init

# Run plan to see the changes that will be made.
terraform plan

# Run apply if the changes look good by confirming the prompt.
terraform apply
```

To verify that the model is running, you can run
```
kubectl get deployment -n benchmark
```
This should show the TGI server running.

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
cp sample-terraform.tfvars terraform.tfvars

# Initialize the Terraform modules.
terraform init

# Run plan to see the changes that will be made.
terraform plan

# Run apply if the changes look good by confirming the prompt.
terraform apply
```

To further interact with the Locust inference benchmark, view the README.md file in `benchmark/tools/locust-load-inference`