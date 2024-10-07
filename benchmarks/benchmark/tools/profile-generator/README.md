# AI on GKE Benchmark Latency Profile Generator

<!-- TOC -->
- [AI on GKE Benchmark Latency Profile Generator](#ai-on-gke-benchmark-latency-profile-generator)
  - [Overview](#overview)
  - [Instructions](#instructions)
    - [Step 1: create output bucket](#step-1-create-output-bucket)
    - [Step 2: create and give service account access to write to output gcs bucket](#step-2-create-and-give-service-account-access-to-write-to-output-gcs-bucket)
      - [\[optional\] give service account access to read Cloud Monitoring metrics](#optional-give-service-account-access-to-read-cloud-monitoring-metrics)
    - [Step 3: create artifact repository for automated Latency Profile Generator docker build](#step-3-create-artifact-repository-for-automated-latency-profile-generator-docker-build)
    - [Step 4: create and configure terraform.tfvars](#step-4-create-and-configure-terraformtfvars)
      - [\[optional\] set-up credentials config with kubeconfig](#optional-set-up-credentials-config-with-kubeconfig)
      - [\[optional\] set up secret token in Secret Manager](#optional-set-up-secret-token-in-secret-manager)
    - [Step 5: login to gcloud](#step-5-login-to-gcloud)
    - [Step 6: terraform initialize, plan and apply](#step-6-terraform-initialize-plan-and-apply)
<!-- TOC -->

## Overview

This deploys the latency profile generator which measures the throuhghput and
latency at various request rates for the model and model server of your choice. 

It currently supports the following frameworks:
- tensorrt_llm_triton
- text generation inference (tgi)
- vllm
- sax
- jetstream

## Instructions

### Step 1: create output bucket

If you followed steps from `../../infra/` for creating your cluster and extra
resources, you will already have an output bucket created for you.
If not, you will have to create and manage your own gcs bucket for storing
benchmarking results.

Set the `output_bucket` in your `terraform.tfvars` to this gcs bucket.

### Step 2: create and give service account access to write to output gcs bucket

The Latency profile generator requires storage.admin access to write output to
the given output gcs bucket. If you followed steps in `../../infra`, then you
already be logged into gcloud have a kubernetes and gcloud service account 
created that has the proper access to the created output bucket. If you are
not logged into gcloud, run the following:

```bash
gcloud auth application-default login
```

If you do not already have an output bucket, create one by running:

```
gcloud storage buckets create gs://OUTPUT_BUCKET
```

To give viewer permissions on the gcs bucket to the gcloud service account,
run the following:

```
gcloud storage buckets add-iam-policy-binding  gs://$OUTPUT_BUCKET/
--member=serviceAccount:$GOOGLE_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com --role=roles/storage.admin
```

Your kubernetes service account will inherit the reader permissions.

You will set the `latency_profile_kubernetes_service_account` in your
`terraform.tfvars` to the kubernetes service account name.

#### [optional] give service account access to read Cloud Monitoring metrics

If `scrape-server-metrics` is set to True, you will need to give the service account access to read
the Cloud Monitoring metrics. You can do so with the following command:

```
gcloud projects add-iam-policy-binding $PROJECT_ID   --member=serviceAccount:$GOOGLE_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com   --role=roles/monitoring.viewer
```

### Step 3: create artifact repository for automated Latency Profile Generator docker build

The latency profile generator rebuilds the docker file on each terraform apply 
if `build_latency_profile_generator_image` is set to true (default is true).
The containers will be pushed to the given `artifact_registry`. This artifact
repository is expected to already exist. If you created your cluster via
`../../infra/`, then an artifact repository was created for you with the same
name as the prefix in the same location as the cluster. You can also create your
own via this command:

```bash
gcloud artifacts repositories create ai-benchmark --location=us-central1 --repository-format=docker
```

### Step 4: create and configure terraform.tfvars

Create a `terraform.tfvars` file. `./sample.tfvars` is provided as an example
file. You can copy the file as a starting point.
Note that at a minimum you will have to change the existing
`credentials_config`, `project_id`, and `artifact_registry`.

```bash
cp ./sample.tfvars terraform.tfvars
```

Fill out your `terraform.tfvars` with the desired model and server configuration, referring to the list of required and optional variables [here](#variables). The following variables are required:
- `credentials_config` - credentials for cluster to deploy Latency Profile Generator benchmark tool on
- `project_id` - project id for enabling dependent services for building Latency Profile Generator artifacts
- `artifact_registry` - artifact registry to upload Latency Profile Generator artifacts to
- `build_latency_profile_generator_image` - Whether latency profile generator image will be built or not
- `targets` - Which model servers are we targeting for benchmarking? Set  the fields on `manual` if intending to benchmark a model server already in the cluster.
- `output_bucket` - gcs bucket to write benchmarking metrics to.
- `latency_profile_kubernetes_service_account` - service account giving access to latency profile generator to write to `output_bucket`
- `k8s_hf_secret` - Name of secret for huggingface token stored in k8s

#### [optional] set-up credentials config with kubeconfig

If your cluster has fleet management enabled, the existing `credentials_config`
can use the fleet host credentials like this:

```bash
credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/global/gkeMemberships/$CLUSTER_NAME"
}
```

If your cluster does not have fleet management enabled, you can use your
cluster's kubeconfig in the `credentials_config`. You must isolate your
cluster's kubeconfig from other clusters in the default kube.config file.
To do this, run the following command:

```bash
KUBECONFIG=~/.kube/${CLUSTER_NAME}-kube.config gcloud container clusters get-credentials $CLUSTER_NAME --location $CLUSTER_LOCATION
```

Then update your `terraform.tfvars` `credentials_config` to the following:

```bash
credentials_config = {
  kubeconfig = {
    path = "~/.kube/${CLUSTER_NAME}-kube.config"
  }
}
```

#### [optional] set up secret token in Secret Manager

A model may require a security token to access it. For example, Llama2 from
HuggingFace is a gated model that requires a
[user access token](https://huggingface.co/docs/hub/en/security-tokens). If the
model you want to run does not require this, skip this step.

If you followed steps from `.../../infra/`, Secret Manager and the user access
token should already be set up. If not, it is strongly recommended that you use
Workload Identity and Secret Manager to access the user access tokens to avoid
adding a plain text token into the terraform state. To do so, follow the
instructions for
[setting up a secret in Secret Manager here](https://cloud.google.com/kubernetes-engine/docs/tutorials/workload-identity-secrets).

Once complete, you should add these related secret values to your
`terraform.tfvars`:

```bash
# ex. "projects/sample-project/secrets/hugging_face_secret"
hugging_face_secret = $SECRET_ID
 # ex. 1
hugging_face_secret_version =  $SECRET_VERSION
```

### Step 5: login to gcloud

Run the following gcloud command for authorization:

```bash
gcloud auth application-default login
```

### Step 6: terraform initialize, plan and apply

Run the following terraform commands:

```bash
# initialize terraform
terraform init

# verify changes
terraform plan

# apply changes
terraform apply
```

The results can be viewed via running the following:
```
kubectl logs job/latency-profile-generator
```
