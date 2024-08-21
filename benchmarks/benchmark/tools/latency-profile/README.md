# AI on GKE Benchmark Latency Profile Generator

<!-- TOC -->
* [AI on GKE Benchmark Latency Profile Generator](#ai-on-gke-benchmark-latency-profile-generator)
  * [Overview](#overview)
  * [Instructions](#instructions)
    * [Step 1: create output bucket](#step-1--create-output-bucket)
    * [Step 2: create and give service account access to write to output gcs bucket](#step-2--create-and-give-service-account-access-to-write-to-output-gcs-bucket)
    * [Step 3: create artifact repository for automated Latency Profile Generator docker build](#step-3--create-artifact-repository-for-automated-latency-profile-generator-docker-build)
    * [Step 4: create and configure terraform.tfvars](#step-4--create-and-configure-terraformtfvars)
      * [[optional] set-up credentials config with kubeconfig](#optional-set-up-credentials-config-with-kubeconfig)
      * [[optional] set up secret token in Secret Manager](#optional-set-up-secret-token-in-secret-manager)
    * [Step 5: login to gcloud](#step-5--login-to-gcloud)
    * [Step 6: terraform initialize, plan and apply](#step-6--terraform-initialize-plan-and-apply)
  * [Inputs](#inputs)
<!-- TOC -->

## Overview

This deploys the latency profile generator which measures the throuhghput and
latency at various request rates for the model and model server of your choice. 

It currently supports the following frameworks:
- tensorrt_llm_triton
- text generation inference (tgi)
- vllm
- sax

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
already have a kubernetes and gcloud service account created that has the proper
access to the created output bucket.

To give viewer permissions on the gcs bucket to the gcloud service account,
run the following:

```
gcloud storage buckets add-iam-policy-binding  gs://$OUTPUT_BUCKET/
--member=serviceAccount:$GOOGLE_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com --role=roles/storage.admin
```

Your kubernetes service account will inherit the reader permissions.

You will set the `lantency_profile_kubernetes_service_account` in your
`terraform.tfvars` to the kubernetes service account name.

### Step 3: create artifact repository for automated Latency Profile Generator docker build

The latency profile generator rebuilds the docker file on each terraform apply.
The containers will be pushed to the given `artifact_registry`. This artifact
repository is expected to already exist. If you created your cluster via
`../../infra/`, then an artifact repository was created for you with the same
name as the prefix in the same location as the cluster. You can also create your
own via this command:

```bash
gcloud artifacts repositories create ai-benchmark --location=us-central1 --repository-format=docker
```


### Step 4: create and configure terraform.tfvars

Create a `terraform.tfvars` file. `./sample-tfvars` is provided as an example
file. You can copy the file as a starting point.
Note that at a minimum you will have to change the existing
`credentials_config`, `project_id`, and `artifact_registry`.

```bash
cp ./sample-tfvars terraform.tfvars
```

Fill out your `terraform.tfvars` with the desired model and server configuration, referring to the list of required and optional variables [here](#variables). The following variables are required:
- `credentials_config` - credentials for cluster to deploy Latency Profile Generator benchmark tool on
- `project_id` - project id for enabling dependent services for building Latency Profile Generator artifacts
- `artifact_registry` - artifact registry to upload Latency Profile Generator artifacts to
- `inference_server_service` - an accessible service name for inference workload to be benchmarked **(Note: If you are using a non-80 port for your model server service, it should be specified here. Example: `my-service-name:9000`)**
- `tokenizer` - must match the model running on the inference workload to be benchmarked
- `inference_server_framework` - the inference workload framework
- `output_bucket` - gcs bucket to write benchmarking metrics to.
- `latency_profile_kubernetes_service_account` - service account giving access to latency profile generator to write to `output_bucket`

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

A results file will appear in GCS bucket specified as `output_bucket` in input
variables.

<!-- BEGIN_TF_DOCS -->

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_artifact_registry"></a> [artifact\_registry](#input\_artifact\_registry) | Artifact registry for storing Latency Profile Generator container. | `string` | `null` | no |
| <a name="input_credentials_config"></a> [credentials\_config](#input\_credentials\_config) | Configure how Terraform authenticates to the cluster. | <pre>object({<br>    fleet_host = optional(string)<br>    kubeconfig = optional(object({<br>      context = optional(string)<br>      path    = optional(string, "~/.kube/config")<br>    }))<br>  })</pre> | n/a | yes |
| <a name="input_hugging_face_secret"></a> [hugging\_face\_secret](#input\_hugging\_face\_secret) | name of the kubectl huggingface secret token; stored in Secret Manager. Security considerations: https://kubernetes.io/docs/concepts/security/secrets-good-practices/ | `string` | `null` | no |
| <a name="input_hugging_face_secret_version"></a> [hugging\_face\_secret\_version](#input\_hugging\_face\_secret\_version) | Secret version in Secret Manager | `string` | `null` | no |
| <a name="input_inference_server_framework"></a> [inference\_server\_framework](#input\_inference\_server\_framework) | Benchmark server configuration for inference server framework. Can be one of: vllm, tgi, tensorrt\_llm\_triton, sax | `string` | `"tgi"` | no |
| <a name="input_inference_server_service"></a> [inference\_server\_service](#input\_inference\_server\_service) | Inference server service | `string` | n/a | yes |
| <a name="input_k8s_hf_secret"></a> [k8s\_hf\_secret](#input\_k8s\_hf\_secret) | Name of secret for huggingface token; stored in k8s | `string` | `null` | no |
| <a name="input_ksa"></a> [ksa](#input\_ksa) | Kubernetes Service Account used for workload. | `string` | `"default"` | no |
| <a name="input_latency_profile_kubernetes_service_account"></a> [latency\_profile\_kubernetes\_service\_account](#input\_latency\_profile\_kubernetes\_service\_account) | Kubernetes Service Account to be used for the latency profile generator tool | `string` | `"sample-runner-ksa"` | no |
| <a name="input_max_num_prompts"></a> [max\_num\_prompts](#input\_max\_num\_prompts) | Benchmark server configuration for max number of prompts. | `number` | `1000` | no |
| <a name="input_max_output_len"></a> [max\_output\_len](#input\_max\_output\_len) | Benchmark server configuration for max output length. | `number` | `256` | no |
| <a name="input_max_prompt_len"></a> [max\_prompt\_len](#input\_max\_prompt\_len) | Benchmark server configuration for max prompt length. | `number` | `256` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace used for model and benchmarking deployments. | `string` | `"default"` | no |
| <a name="input_output_bucket"></a> [output\_bucket](#input\_output\_bucket) | Bucket name for storing results | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id of existing or created project. | `string` | n/a | yes |
| <a name="input_templates_path"></a> [templates\_path](#input\_templates\_path) | Path where manifest templates will be read from. Set to null to use the default manifests | `string` | `null` | no |
| <a name="input_tokenizer"></a> [tokenizer](#input\_tokenizer) | Benchmark server configuration for tokenizer. | `string` | `"tiiuae/falcon-7b"` | no |

<!-- END_TF_DOCS -->
