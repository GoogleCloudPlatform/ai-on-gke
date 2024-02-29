# AI on GKE Benchmark TGI Server

<!-- BEGIN TOC -->
- [AI on GKE Benchmark TGI Server](#ai-on-gke-benchmark-tgi-server)
  - [Overview](#overview)
  - [Instructions](#instructions)
    - [Step 1: create and configure terraform.tfvars](#step-1-create-and-configure-terraformtfvars)
      - [Determine number of gpus](#determine-number-of-gpus)
      - [\[optional\] set-up credentials config with kubeconfig](#optional-set-up-credentials-config-with-kubeconfig)
      - [\[optional\] set up secret token in Secret Manager](#optional-set-up-secret-token-in-secret-manager)
    - [\[Optional\] Step 2: configure alternative storage](#optional-step-2-configure-alternative-storage)
    - [Step 3: login to gcloud](#step-3-login-to-gcloud)
    - [Step 4: terraform initialize, plan and apply](#step-4-terraform-initialize-plan-and-apply)
  - [Variables](#variables)
<!-- END TOC -->

## Overview

This stage deploys a [Text Generation Inference](https://huggingface.co/docs/text-generation-inference/en/index) server.

## Instructions

### Step 1: create and configure terraform.tfvars

Create a `terraform.tfvars` file. `sample-terraform.tfvars` is provided as an example file. You can copy the file as a starting point. Note that you will have to change the existing `credentials_config`.

```bash
cp sample-terraform.tfvars terraform.tfvars
```

Fill out your `terraform.tfvars` with the desired model and server configuration, referring to the list of required and optional variables [here](#variables). Variables `credentials_config` are required.

Optionally configure HPA (Horizontal Pod Autoscaling) by setting `hpa_type`. Note: GMP (Google Managed Prometheus) must be enabled on this cluster (which is the default) to scale based on custom metrics. See `autoscaling.md` for more details.

#### Determine number of gpus

`gpu_count` should be configured respective to the size of the model with some overhead for the kv cache. Here's an example on figuring out how many GPUs you need to run a model:

TGI defaults to bfloat16 for running supported models on GPUs. For a model with dtype of FP16 or bfloat16, each parameter requires 16 bits. A 7 billion parameter model requires a minimum of 7 billion * 16 bits = 14 GB of GPU memory. A single L4 GPU has 24GB of GPU memory. 1 L4 GPU is sufficient to run the `tiiuae/falcon-7b` model with plenty of overhead for the kv cache.

Note that Huggingface TGI server supports gpu_count equal to one of 1, 2, 4, or 8.

#### [optional] set-up credentials config with kubeconfig

If you created your cluster with steps from `../../infra/` or with fleet management enabled, the existing `credentials_config` must use the fleet host credentials like this:

```bash
credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/global/gkeMemberships/$CLUSTER_NAME"
}
```

If you created your own cluster without fleet management enabled, you can use your cluster's kubeconfig in the `credentials_config`. You must isolate your cluster's kubeconfig from other clusters in the default kube.config file. To do this, run the following command:

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

A model may require a security token to access it. For example, Llama2 from HuggingFace is a gated model that requires a [user access token](https://huggingface.co/docs/hub/en/security-tokens). If the model you want to run does not require this, skip this step.

If you followed steps from `../../infra/`, Secret Manager and the user access token should already be set up. If not, it is strongly recommended that you use Workload Identity and Secret Manager to access the user access tokens to avoid adding a plain text token into the terraform state. To do so, follow the instructions for [setting up a secret in Secret Manager here](https://cloud.google.com/kubernetes-engine/docs/tutorials/workload-identity-secrets).

Once complete, you should add these related secret values to your `terraform.tfvars`:

```bash
# ex. "projects/sample-project/secrets/hugging_face_secret"
hugging_face_secret = $SECRET_ID
 # ex. 1
hugging_face_secret_version =  $SECRET_VERSION
```

### [Optional] Step 2: configure alternative storage

By default, the TGI yaml spec assumes that the cluster has [local SSD-backed ephemeral storage](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/local-ssd) available.

If you wish to use a different storage option with the TGI server, you can edit the `./manifest-templates/text-generation-inference.tftpl` directly with your desired storage setup.


### Step 3: login to gcloud

Run the following gcloud command for authorization:

```bash
gcloud auth application-default login
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
<!-- BEGIN TFDOC -->
## Variables

| name                                            | description                                                                                                                                              |                                                                                                                                                                             type                                                                                                                                                                             | required |                   default                   |
| ----------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: | :------: | :-----------------------------------------: |
| [credentials_config](variables.tf#L17)          | Configure how Terraform authenticates to the cluster.                                                                                                    | <code title="object&#40;&#123;&#10;  fleet_host &#61; optional&#40;string&#41;&#10;  kubeconfig &#61; optional&#40;object&#40;&#123;&#10;    context &#61; optional&#40;string&#41;&#10;    path    &#61; optional&#40;string, &#34;&#126;&#47;.kube&#47;config&#34;&#41;&#10;  &#125;&#41;&#41;&#10;&#125;&#41;">object&#40;&#123;&#8230;&#125;&#41;</code> |    ✓     |                                             |
| [gpu_count](variables.tf#L55)                   | Tensor parallelism. This is the number of gpus the server should use. Note that Huggingface TGI server supports gpu_count equal to one of 1, 2, 4, or 8. |
| <code>number</code>                             |                                                                                                                                                          |                                                                                                                                                                        <code>1</code>                                                                                                                                                                        |
| [hugging_face_secret](variables.tf#L81)         | Secret id in Secret Manager. Required if your model requires a Huggingface user access token.                                                            |                                                                                                                                                                     <code>string</code>                                                                                                                                                                      |          |              <code>null</code>              |
| [hugging_face_secret_version](variables.tf#L88) | Secret version in Secret Manager. Required if your model requires a Huggingface user access token.                                                       |                                                                                                                                                                     <code>string</code>                                                                                                                                                                      |          |              <code>null</code>              |
| [ksa](variables.tf#L62)                         | Kubernetes Service Account used for workload.                                                                                                            |                                                                                                                                                                     <code>string</code>                                                                                                                                                                      |          |       <code>&#34;default&#34;</code>        |
| [model_id](variables.tf#L48)                    | Model used for inference.                                                                                                                                |                                                                                                                                                                     <code>string</code>                                                                                                                                                                      |          | <code>&#34;tiiuae&#47;falcon-7b&#34;</code> |
| [namespace](variables.tf#L36)                   | Namespace to deploy server in.                                                                                                                           |                                                                                                                                                                     <code>string</code>                                                                                                                                                                      |          |       <code>&#34;default&#34;</code>        |
<!-- END TFDOC -->
