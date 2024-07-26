# AI on GKE Benchmarking

This framework enables you to run automated benchmarks on GKE for AI workloads via Terraform automation.
You can find the current set of supported cluster deployments under `infra/` and the supported inference servers
under `inference-server/`.

Note that you can run any stage separate from another. For example, you can deploy your own inference server
on a cluster created via these terraform scripts. And vice versa, you can deploy the inference servers
via these terraform scripts on a Standard cluster that you've created yourself.

## Pre-requisites

### gcloud auth

This tutorial assumes you have access to use google storage APIs via Application Default Credentials (ADC).
To login, you can run the following:

```
gcloud auth application-default login
```

### Terraform

Install Terraform by following the documentation at https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli.
This requires a minimum Terraform version of 1.7.4

### python

Python script used in this tutorial assumes in your environment you are running Python >= 3.9

You may need to run pip install -r benchmark/dataset/ShareGPT_v3_unflitered_cleaned_split/requirements.txt to install the library dependencies. (Optionally, you can run this within a venv, i.e. python3 -m venv ./venv && source ./venv/bin/activate && pip install ...)

## Deploy and benchmark an ML model

This section goes over an end to end example to deploy and benchmark the Falcon 7b model using [TGI](https://huggingface.co/docs/text-generation-inference/en/index) on a Standard GKE Cluster with GPUs.

Each step below has more details in their respective directoy README.md. It is recommended
that you read through the available options at least once when testing your own models.

At a high level, running an inference benchmark in GKE involves these five steps:
1. Create the cluster
2. Configure the cluster
3. Deploy the inference server
4. Deploy the benchmark
5. Run a benchmark and review the results
6. Clean up

### 1. Create the cluster

Set up the infrastructure by creating a GKE cluster with appropriate accelerator
configuration.

To create a GPU cluster, in the ai-on-gke/benchmarks folder run:
```
# Stage 1 creates the cluster.
cd infra/stage-1

# Copy the sample variables and update the project ID, cluster name and
# other parameters as needed in the `terraform.tfvars` file.
cp ./sample-tfvars/gpu-sample.tfvars terraform.tfvars

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
gcloud container fleet memberships get-credentials <cluster-name> --project <project-id>

# Run a kubectl command to verify
kubectl get nodes
```

### 2. Configure the cluster

To configure the cluster to run inference workloads we need to set up workload identity, GCS Fuse and DCGM for GPU metrics. In the ai-on-gke/benchmarks folder run:
```
# Stage 2 configures the cluster for running inference workloads.
cd infra/stage-2

# Copy the sample variables and update the project number and cluster name in
# the fleet_host variable:
# "https://connectgateway.googleapis.com/v1/projects/<project-number>/locations/global/gkeMemberships/<cluster-name>"
# and the project name and bucket name parameters as needed in the `terraform.tfvars` file.
# You can specify a new bucket name in which case it will be created.
cp ./sample-tfvars/gpu-sample.tfvars terraform.tfvars

# Initialize the Terraform modules.
terraform init

# Run plan to see the changes that will be made.
terraform plan

# Run apply if the changes look good by confirming the prompt.
terraform apply
```

### 3. Deploy the inference server

To deploy TGI with a sample model, in the ai-on-gke/benchmarks folder run:
```
# text-generation-inference is the inference workload we'll deploy.
cd inference-server/text-generation-inference

# Copy the sample variables and update the project number and cluster name in
# the fleet_host variable:
# "https://connectgateway.googleapis.com/v1/projects/<project-number>/locations/global/gkeMemberships/<cluster-name>"
# in the `terraform.tfvars` file.
cp ./sample-terraform.tfvars terraform.tfvars

# Initialize the Terraform modules.
terraform init

# Run plan to see the changes that will be made.
terraform plan

# Run apply if the changes look good by confirming the prompt.
terraform apply
```

It may take a minute or two for the inference server to be ready to serve. To verify that the model is running, you can run:
```
kubectl get deployment -n benchmark
```
This will show the status of the TGI server running.

### 4. Deploy the benchmark

#### Prepare the benchmark dataset

To prepare the dataset for the Locust inference benchmark, in the ai-on-gke/benchmarks folder run:
```
# This folder contains a script that prepares the prompts for ShareGPT_v3_unflitered_cleaned_split dataset
# that works out of the box with the locust benchmarking expected format.
cd benchmark/dataset/ShareGPT_v3_unflitered_cleaned_split

# Process and upload the dataset to the bucket created in the earlier steps.
python3 upload_sharegpt.py --gcs_path="gs://${PROJECT_ID}-ai-gke-benchmark-fuse/ShareGPT_V3_unfiltered_cleaned_split_filtered_prompts.txt"
```

#### Deploy the benchmarking tool

To deploy the Locust inference benchmark with the above model, in the ai-on-gke/benchmarks folder run:
```
# This folder contains the benchmark tool that generates requests for your workload
cd benchmark/tools/locust-load-inference

# Copy the sample variables and update the project number and cluster name in
# the fleet_host variable:
# "https://connectgateway.googleapis.com/v1/projects/<project-number>/locations/global/gkeMemberships/<cluster-name>"
# in the `terraform.tfvars` file.
cp ./sample-tfvars/tgi-sample.tfvars terraform.tfvars

# Initialize the Terraform modules.
terraform init

# Run plan to see the changes that will be made.
terraform plan

# Run apply if the changes look good by confirming the prompt.
terraform apply
```

To further interact with the Locust inference benchmark, view the README.md file in `benchmark/tools/locust-load-inference`

### 5. Run a benchmark and review the results

An end to end Locust benchmark that runs for a given amount of time can be triggered via a curl command to the Locust Runner service:

```
# get the locust runner endpoint
kubectl get service -n benchmark locust-runner-api

# Using the endpoint, run this curl command to instantiate the test
curl -XGET http://$RUNNER_ENDPOINT_IP:8000/run
```

A results file will appear in the GCS bucket specified as output_bucket in input variables once the benchmark is completed. Metrics and Locust statistics are visible under the [Cloud Monitoring metrics explorer](http://pantheon.corp.google.com/monitoring/metrics-explorer). In the ai-on-gke/benchmarks/benchmark/tools/locust-load-inference, run the following command to create a sample custom dashboard for the above related example:
```
# apply the sample dashboard to easily view and explore metrics
gcloud monitoring dashboards create   --config-from-file ./sample-dashboards/tgi-dashboard.yaml
```

View the results in the [Cloud Monitoring Dashboards](https://pantheon.corp.google.com/monitoring/dashboards) underneath "Benchmark".

For more ways to interact with the locust benchmarking tooling, see the instructions in the [locust-load-inference README.md here](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/benchmarks/benchmark/tools/locust-load-inference/README.md#step-9-start-an-end-to-end-benchmark).

### 6. Clean Up
To clean up the above setup, in the ai-on-gke/benchmarks folder run:

```
# Run destroy on locust load generator
cd benchmark/tools/locust-load-inference
terraform destroy

# Run destroy on TGI workload
cd ../../../inference-server/text-generation-inference
terraform destroy

# Run destroy on infra/stage-2 resources
#
# NOTE: the gcs buckets will not be destroyed unless you delete all of 
# the files in the existing gcs buckets (benchmark output and 
# benchmark data buckets). Keeping the gcs buckets does not interfere 
# with future terraform commands.
cd ../../infra/stage-2
terraform destroy

# Run destroy on infra/stage-1 resources
cd ../stage-1
terraform destroy
```