# Benchmark vLLM on GKE

>[!WARNING]
>This guide and associated code are **deprecated** and no longer maintained.
>
>Please refer to the [GKE AI Labs website](https://gke-ai-labs.dev) for the latest tutorials and quick start solutions.

This stage deploys the [vLLM](https://docs.vllm.ai/en/latest/index.html) inference server.

## Instructions

### Step 1: create and configure terraform.tfvars

Create a `terraform.tfvars` file. `sample-terraform.tfvars` is provided as an
example file. You can copy the file as a starting point. Note that you will have
to change the existing `credentials_config`.

```bash
cp sample-terraform.tfvars terraform.tfvars
```

Fill out your `terraform.tfvars` with the desired model and server
configuration, referring to the list of required and optional variables
[here](#inputs). Variables `credentials_config` are required.

#### Determine number of gpus

`gpu_count` should be configured respective to the size of the model with some
overhead for the kv cache. Here's an example on figuring out how many GPUs you
need to run a model:

vLLM defaults to bfloat16 for running supported models on GPUs. For a model with
dtype of FP16 or bfloat16, each parameter requires 16 bits. A 7 billion
parameter model requires a minimum of 7 billion * 16 bits = 14 GB of GPU memory.
A single L4 GPU has 24GB of GPU memory. 1 L4 GPU is sufficient to run the
`tiiuae/falcon-7b` model with plenty of overhead for the kv cache.

Note that vLLM server supports gpu_count equal to one of 1, 2, 4, or 8.

#### [optional] set-up credentials config with kubeconfig

If you created your cluster with steps from `../../infra/` or with fleet
management enabled, the existing `credentials_config` must use the fleet host
credentials like this:

```bash
credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/global/gkeMemberships/$CLUSTER_NAME"
}
```

If you created your own cluster without fleet management enabled, you can use
your cluster's kubeconfig in the `credentials_config`. You must isolate your
cluster's kubeconfig from other clusters in the default kube.config file. To do
this, run the following command:

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

If you followed steps from `../../infra/`, Secret Manager and the user access
token should already be set up. If not, it is strongly recommended that you use
Workload Identity and Secret Manager to access the user access tokens to avoid
adding a plain text token into the terraform state. To do so, follow the
instructions for [setting up a secret in Secret Manager here](https://cloud.google.com/kubernetes-engine/docs/tutorials/workload-identity-secrets).

Once complete, you should add these related secret values to your
`terraform.tfvars`:

```bash
# ex. "projects/sample-project/secrets/hugging_face_secret"
hugging_face_secret = $SECRET_ID
 # ex. 1
hugging_face_secret_version =  $SECRET_VERSION
```

### [Optional] Step 2: configure alternative storage

By default, the vLLM yaml spec assumes that the cluster has [local SSD-backed ephemeral storage](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/local-ssd)
available.

If you wish to use a different storage option with the vLLM server, you can edit
the `./manifest-templates/text-generation-inference.tftpl` directly with your
desired storage setup.


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

<!-- BEGIN_TF_DOCS -->

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_credentials_config"></a> [credentials\_config](#input\_credentials\_config) | Configure how Terraform authenticates to the cluster. | <pre>object({<br>    fleet_host = optional(string)<br>    kubeconfig = optional(object({<br>      context = optional(string)<br>      path    = optional(string, "~/.kube/config")<br>    }))<br>  })</pre> | n/a | yes |
| <a name="input_gpu_count"></a> [gpu\_count](#input\_gpu\_count) | Parallelism based on number of gpus. | `number` | `1` | no |
| <a name="input_hugging_face_secret"></a> [hugging\_face\_secret](#input\_hugging\_face\_secret) | Secret id in Secret Manager | `string` | `null` | no |
| <a name="input_hugging_face_secret_version"></a> [hugging\_face\_secret\_version](#input\_hugging\_face\_secret\_version) | Secret version in Secret Manager | `string` | `null` | no |
| <a name="input_ksa"></a> [ksa](#input\_ksa) | Kubernetes Service Account used for workload. | `string` | `"default"` | no |
| <a name="input_model_id"></a> [model\_id](#input\_model\_id) | Model used for inference. | `string` | `"tiiuae/falcon-7b"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace used for vLLM resources. | `string` | `"default"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id of existing or created project. | `string` | n/a | yes |
| <a name="input_secret_templates_path"></a> [secret\_templates\_path](#input\_secret\_templates\_path) | Path where secret configuration manifest templates will be read from. Set to null to use the default manifests | `string` | `null` | no |
| <a name="input_templates_path"></a> [templates\_path](#input\_templates\_path) | Path where manifest templates will be read from. Set to null to use the default manifests | `string` | `null` | no |

<!-- END_TF_DOCS -->