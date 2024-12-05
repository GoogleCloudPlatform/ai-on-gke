# AI on GKE Benchmark Infrastructure

<!-- BEGIN TOC -->
- [AI on GKE Benchmark Infrastructure](#ai-on-gke-benchmark-infrastructure)
  - [Overview](#overview)
  - [Instructions](#instructions)
    - [Step 1: create and configure terraform.tfvars](#step-1-create-and-configure-terraformtfvars)
    - [Step 2: login to gcloud](#step-2-login-to-gcloud)
    - [\[Optional\] Step 3: set up secret value in Secret Manager](#optional-step-3-set-up-secret-value-in-secret-manager)
    - [Step 4: terraform initialize, plan and apply](#step-4-terraform-initialize-plan-and-apply)
    - [Step 5: verify](#step-5-verify)
  - [Variables](#variables)
  - [Outputs](#outputs)
<!-- END TOC -->

## Overview

This stage deploys workloads that run on a Standard GKE cluster optimized to run AI models on GPU accelerators. The cluster configuration follows the
Google best practices described in:
[GCP Fast Fabric modules](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric),
as well as the [GKE Jumpstart examples](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/blob/gke-blueprints/0-redis/blueprints/gke/jumpstart/jumpstart-0-infra/README.md).

In particular, stage-2 provisions:
- Workload Identity
- GCS Fuse
- Nvidia DCGM

## Instructions

### Step 1: create and configure terraform.tfvars

Create a `terraform.tfvars` file. `./sample-tfvars/gpu-sample.tfvars` is provided as an example file. You can copy the file as a starting point. Note that you will have to change the existing `project_id`.

```bash
cp ./sample-tfvars/gpu-sample.tfvars terraform.tfvars
```

Fill out your `terraform.tfvars` with the desired project and cluster configuration, referring to the list of required and optional variables [here](#variables). Variables `credentials_config` and `project_id` are required.

### Step 2: login to gcloud

Run the following gcloud command for authorization:

```bash
gcloud auth application-default login
```

### [Optional] Step 3: set up secret value in Secret Manager

A model may require a security token to access it. For example, Llama2 from HuggingFace is a gated model that requires a [user access token](https://huggingface.co/docs/hub/en/security-tokens).

You will need to add the secret value manually to the Secret Manager. This is to avoid adding a plain text token into the terraform state. To do so, [follow the instructions for creating a secret in your project here](https://cloud.google.com/secret-manager/docs/creating-and-accessing-secrets#before_you_begin).

Once complete, you should add these related secret values to your `terraform.tfvars`:

```bash
`secret_name` = $SECRET_ID                   # eg. "hugging_face_secret"
`secret_location` =  $SECRET_LOCATION        # eg. "europe-central2"
```

### Step 4: terraform initialize, plan and apply

Run the following terraform commands:

```bash
# initialize terraform
terraform init

# verify changes
terraform plan

# apply changes
terraform apply
```

### Step 5: verify

To verify that the cluster has been set up correctly, run
```
# Get credentials using fleet membership
gcloud container fleet memberships get-credentials <cluster-name>

# Run a kubectl command to verify
kubectl get nodes
```

<!-- BEGIN TFDOC -->
## Variables

| name | description | type | required | default |
|---|---|:---:|:---:|:---:|
| [bucket_name](variables.tf#L86) | GCS bucket name | <code>string</code> | ✓ |  |
| [credentials_config](variables.tf#L17) | Configure how Terraform authenticates to the cluster. | <code title="object&#40;&#123;&#10;  fleet_host &#61; optional&#40;string&#41;&#10;  kubeconfig &#61; optional&#40;object&#40;&#123;&#10;    context &#61; optional&#40;string&#41;&#10;    path    &#61; optional&#40;string, &#34;&#126;&#47;.kube&#47;config&#34;&#41;&#10;  &#125;&#41;&#41;&#10;&#125;&#41;">object&#40;&#123;&#8230;&#125;&#41;</code> | ✓ |  |
| [project_id](variables.tf#L36) | Project id of existing or created project. | <code>string</code> | ✓ |  |
| [bucket_location](variables.tf#L92) | Location of GCS bucket | <code>string</code> |  | <code>&#34;US&#34;</code> |
| [benchmark_runner_kubernetes_service_account](variables.tf#L60) | Kubernetes Service Account to be used for Benchmark Tool runner | <code>string</code> |  | <code>&#34;locust-runner-ksa&#34;</code> |
| [benchmark_runner_google_service_account](variables.tf#L60) | Name for the Google Service Account to be used for Benchmark Tool runner | <code>string</code> |  | <code>&#34;locust-runner-sa&#34;</code> |
| [google_service_account](variables.tf#L73) | Name for the Google Service Account to be used for benchmark | <code>string</code> |  | <code>&#34;benchmark-sa&#34;</code> |
| [google_service_account_create](variables.tf#L80) | Create Google service account to bind to a Kubernetes service account. | <code>bool</code> |  | <code>true</code> |
| [kubernetes_service_account](variables.tf#L60) | Name for the Kubernetes Service Account to be used for benchmark | <code>string</code> |  | <code>&#34;benchmark-ksa&#34;</code> |
| [kubernetes_service_account_create](variables.tf#L67) | Create Kubernetes Service Account to be used for benchmark | <code>bool</code> |  | <code>true</code> |
| [namespace](variables.tf#L41) | Namespace used for AI benchmark cluster resources. | <code>string</code> |  | <code>&#34;benchmark&#34;</code> |
| [namespace_create](variables.tf#L48) | Create Kubernetes namespace | <code>bool</code> |  | <code>true</code> |
| [secret_location](variables.tf#L105) | Location of secret | <code>string</code> |  | <code>null</code> |
| [secret_name](variables.tf#L98) | Secret name | <code>string</code> |  | <code>null</code> |
| [workload_identity_create](variables.tf#L54) | Setup Workload Identity configuration for newly created GKE cluster. Set to false to skip. | <code>bool</code> |  | <code>true</code> |
| [nvidia_dcgm_create](variables.tf#L136) | Determines if DCGM resources should be added to the cluster. Used in capturing GPU metrics. | <code>bool</code> |  | <code>true</code> |
| [gcs_fuse_create](variables.tf#L136) | Gives the model server service account Storage Admin access to the model store bucket | <code>bool</code> |  | <code>true</code> |

## Outputs

| name | description | sensitive |
|---|---|:---:|
| [created_resources](outputs.tf#L1) | Created resources |  |
<!-- END TFDOC -->
