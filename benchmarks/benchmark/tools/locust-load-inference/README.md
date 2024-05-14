# AI on GKE Benchmark Locust

<!-- BEGIN TOC -->
- [AI on GKE Benchmark Locust](#ai-on-gke-benchmark-locust)
  - [Overview](#overview)
  - [Instructions](#instructions)
    - [Step 1: prepare benchmark prompts](#step-1-prepare-benchmark-prompts)
    - [Step 2: create and give service account access to view dataset](#step-2-create-and-give-service-account-access-to-view-dataset)
    - [Step 3: create output bucket](#step-3-create-output-bucket)
    - [Step 4: create and give service account access to write to output gcs bucket](#step-4-create-and-give-service-account-access-to-write-to-output-gcs-bucket)
    - [Step 5: create artifact repository for automated Locust docker build](#step-5-create-artifact-repository-for-automated-locust-docker-build)
    - [Step 6: create and configure terraform.tfvars](#step-6-create-and-configure-terraformtfvars)
      - [\[optional\] set-up credentials config with kubeconfig](#optional-set-up-credentials-config-with-kubeconfig)
      - [\[optional\] set up secret token in Secret Manager](#optional-set-up-secret-token-in-secret-manager)
    - [Step 7: login to gcloud](#step-7-login-to-gcloud)
    - [Step 8: terraform initialize, plan and apply](#step-8-terraform-initialize-plan-and-apply)
    - [Step 9: start an end to end benchmark](#step-9-start-an-end-to-end-benchmark)
      - [option 1: initiate a single end to end Locust benchmark run via curl command](#option-1-initiate-a-single-end-to-end-locust-benchmark-run-via-curl-command)
      - [option 2: interactive benchmark with locust web ui](#option-2-interactive-benchmark-with-locust-web-ui)
    - [Step 10: viewing metrics](#step-10-viewing-metrics)
    - [Additional Tips](#additional-tips)
  - [Variables](#variables)
<!-- END TOC -->

## Overview

This deploys an inferencing benchmarking tool utilizing [Locust](http://locust.io/). Locust offers a scalable distributed benchmarking framework that can run from anywhere. The terraform scripts are configured to deploy the Locust benchmarking tool on a given GKE cluster.

The Locust inferencing benchmarking tool measures the following:
- throughput (eg. requests / sec)
- request latency (ms)

Metrics are defined in the `locust-runner/metrics.yaml` file. You can customize metrics gathered by changing this file. The Locust master is run with side-car container allowing Locust metrics to be scraped by the PodMonitoring object running on the GKE cluster. The metrics are visible on the Cloud Monitoring dashboard.

The Locust benchmarking tool currently supports these frameworks:
- sax
- tensorrt_llm_triton
- text generation inference (tgi)
- vllm

## Instructions

### Step 1: prepare benchmark prompts

The prompts are downloaded from a given gcs path prior to starting the Locust tasks. Prompts are read in line by line. Each prompt should be stored on its own new line, eg.:

```
This is my first prompt.\n
This is my second prompt.\n
```

Example prompt datasets are available in the "../../dataset" folder with python scripts and instructions on how to make the dataset available for consumption by this benchmark. The dataset used in the `sample-terraform.tfvars` is the "ShareGPT_v3_unflitered_cleaned_split".

You will set the `gcs_path` in your `terraform.tfvars` to this gcs path containing your prompts.

### Step 2: create and give service account access to view dataset

The Locust workload requires storage.admin access to view the dataset in the given gcs bucket. If you are running with workload identity, it obtains this access via a kubernetes service account that is backed by a gcloud service account. If you followed steps in `../../infra`, then you already have a kubernetes and gcloud service account created that you can use here.

To give viewer permissions on the gcs bucket to the gcloud service account, run the following:

```
gcloud storage buckets add-iam-policy-binding  gs://$BUCKET
--member=serviceAccount:$GOOGLE_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com --role=roles/storage.admin
```

Your kubernetes service account will inherit the reader permissions.

You will set the `ksa` in your `terraform.tfvars` to the kubernetes service account name.

### Step 3: create output bucket

If you followed steps from `../../infra/` for creating your cluster and extra resources, you will already have an output bucket created for you.  If not, you will have to create and manage your own gcs bucket for storing benchmarking results.

Set the `output_bucket` in your `terraform.tfvars` to this gcs bucket.

### Step 4: create and give service account access to write to output gcs bucket

The Locust workload requires storage.admin access to write output to the given output gcs bucket. If you followed steps in `../../infra`, then you already have a kubernetes and gcloud service account created that has the proper access to the created output bucket.

To give viewer permissions on the gcs bucket to the gcloud service account, run the following:

```
gcloud storage buckets add-iam-policy-binding  gs://$OUTPUT_BUCKET/
--member=serviceAccount:$GOOGLE_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com --role=roles/storage.admin
```

Your kubernetes service account will inherit the reader permissions.

You will set the `locust_runner_kubernetes_service_account` in your `terraform.tfvars` to the kubernetes service account name.

### Step 5: create artifact repository for automated Locust docker build

Locust rebuilds the docker file on each terraform apply. The containers will be pushed to the given `artifact_registry`. This artifact repository is expected to already exist. If you created your cluster via `../../infra/`, then an artifact repository was created for you with the same name as the prefix in the same location as the cluster. You can also create your own via this command:

```bash
gcloud artifacts repositories create ai-benchmark --location=us-central1 --repository-format=docker
```


### Step 6: create and configure terraform.tfvars

Create a `terraform.tfvars` file. `sample-terraform.tfvars` is provided as an example file. You can copy the file as a starting point. Note that at a minimum you will have to change the existing `credentials_config`, `project_id`, and `artifact_registry`.

```bash
cp sample-terraform.tfvars terraform.tfvars
```

Fill out your `terraform.tfvars` with the desired model and server configuration, referring to the list of required and optional variables [here](#variables). The following variables are required:
- `credentials_config` - credentials for cluster to deploy Locust benchmark tool on
- `project_id` - project id for enabling dependent services for building locust artifacts
- `artifact_registry` - artifact registry to upload locust artifacts to
- `inference_server_service` - an accessible service name for inference workload to be benchmarked **(Note: If you are using a non-80 port for your model server service, it should be specified here. Example: `my-service-name:9000`)**
- `tokenizer` - must match the model running on the inference workload to be benchmarked
- `inference_server_framework` - the inference workload framework
- `request_type` - **required if using gRPC**
- `gcs_path` - gcs bucket where prompts to use during benchmark are stored
- `ksa` - access for the `gcs_path` gcs bucket where prompts are stored.
- `output_bucket` - gcs bucket to write benchmarking metrics to.
- `locust_runner_kubernetes_service_account` - service account giving access to locust runner to write to `output_bucket`

#### [optional] set-up credentials config with kubeconfig

If your cluster has fleet management enabled, the existing `credentials_config` can use the fleet host credentials like this:

```bash
credentials_config = {
  fleet_host = "https://connectgateway.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/global/gkeMemberships/$CLUSTER_NAME"
}
```

If your cluster does not have fleet management enabled, you can use your cluster's kubeconfig in the `credentials_config`. You must isolate your cluster's kubeconfig from other clusters in the default kube.config file. To do this, run the following command:

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

If you followed steps from `.../../infra/`, Secret Manager and the user access token should already be set up. If not, it is strongly recommended that you use Workload Identity and Secret Manager to access the user access tokens to avoid adding a plain text token into the terraform state. To do so, follow the instructions for [setting up a secret in Secret Manager here](https://cloud.google.com/kubernetes-engine/docs/tutorials/workload-identity-secrets).

Once complete, you should add these related secret values to your `terraform.tfvars`:

```bash
# ex. "projects/sample-project/secrets/hugging_face_secret"
hugging_face_secret = $SECRET_ID
 # ex. 1
hugging_face_secret_version =  $SECRET_VERSION
```

### Step 7: login to gcloud

Run the following gcloud command for authorization:

```bash
gcloud auth application-default login
```

### Step 8: terraform initialize, plan and apply

Run the following terraform commands:

```bash
# initialize terraform
terraform init

# verify changes
terraform plan

# apply changes
terraform apply
```

### Step 9: start an end to end benchmark

#### option 1: initiate a single end to end Locust benchmark run via curl command

An end to end Locust benchmark that runs for a given amount of time can be triggered via a curl command to the Locust Runner service. The results of the single run are stored in the given `output_bucket` after the given duration of time.

`Locust-runner/` directory contains the configuration for the simple FastAPI service Locust Runner.


To run benchmarking, grab the runner endpoint ip via:

```bash
kubectl get service -n $LOCUST_NAMESPACE locust-runner-api
```

Using the IP, run this curl command to instantiate the test:

```bash
curl -XGET http://$RUNNER_ENDPOINT_IP:8000/run
```

A results file will appear in GCS bucket specified as `output_bucket` in input variables.
Metrics and Locust statistics are also visible under Cloud Monitoring dashboard.

#### option 2: interactive benchmark with locust web ui

Locust offers an interactive metrics collection experience via its web ui. Users can trigger and stop benchmarks manually, and view graphs of real-time generated data from Locust native metrics.

`Locust-docker/` directory contains the Locust service. The Locust web UI can be accessed via this service.

Note that Locust metrics will be visible in the Locust UI itself and in Cloud Monitoring dashboards.
No GCS report will be generated in the manual triggered benchmark case.

To utilize Locust's web ui, grab the Locust service's External IP via this command:

```bash
kubectl get service -n $LOCUST_NAMESPACE locust-master-web
```

In a web browser, visit the following website:
```
http://$LOCUST_SERVICE_IP:8089
```

### Step 10: viewing metrics

Locust and custom inferencing metrics calculated by locust are exported to cloud monitoring. Metrics are stored in the prometheus namespace, eg:

resource.type="prometheus_target"
metric.type="prometheus.googleapis.com/locust_*"

You can use the cloud monitoring dashboard to view charts of these metrics.

### Additional Tips

To change the benchmark configuration, you will have to rerun terraform destroy and apply.

<!-- BEGIN_TF_DOCS -->

## Variables

| Name                                                                                                                 | Description                                                                                                                 | Type                                                                                                                                                                                                        | Default              | Required |
| -------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- | :------: |
| <a name="input_artifact_registry"></a> [artifact\_registry](#input\_artifact\_registry)                              | Artifact registry for storing Locust container                                                                              | `string`                                                                                                                                                                                                    | `null`               |   yes    |
| <a name="input_best_of"></a> [best\_of](#input\_best\_of)                                                            | Benchmark server configuration for best of.                                                                                 | `number`                                                                                                                                                                                                    | `1`                  |    no    |
| <a name="input_credentials_config"></a> [credentials\_config](#input\_credentials\_config)                           | Configure how Terraform authenticates to the cluster.                                                                       | <pre>object({<br>    fleet_host = optional(string)<br>    kubeconfig = optional(object({<br>      context = optional(string)<br>      path    = optional(string, "~/.kube/config")<br>    }))<br>  })</pre> | n/a                  |   yes    |
| <a name="input_gcs_path"></a> [gcs\_path](#input\_gcs\_path)                                                         | Benchmark server configuration for gcs\_path for downloading prompts.                                                       | `string`                                                                                                                                                                                                    | n/a                  |   yes    |
| <a name="input_inference_server_framework"></a> [inference\_server\_framework](#input\_inference\_server\_framework) | Benchmark server configuration for inference server framework. Can be one of: vllm, tgi, tensorrt\_llm\_triton, sax, or jetstream  | `string`                                                                                                                                                                                                    | `"tgi"`              |   yes    |
| <a name="input_request_type"></a> [request\_type](#input\_request\_type) | Protocol to use when making requests to the model server. Can be `grpc` or `http` | `string`                                                                                                                                                                                                    | `"http"`              |   no    |
| <a name="input_inference_server_ip"></a> [inference\_server\_ip](#input\_inference\_server\_ip)                      | Inference server ip address                                                                                                 | `string`                                                                                                                                                                                                    | n/a                  |   yes    |
| <a name="input_ksa"></a> [ksa](#input\_ksa)                                                                          | Kubernetes Service Account used for workload.                                                                               | `string`                                                                                                                                                                                                    | `"default"`          |    no    |
| <a name="locust_runner_kubernetes_service_account"></a> [locust\_runner\_kubernetes\_service\_account](#locust\_runner\_kubernetes\_service\_account)                                                                          | "Kubernetes Service Account to be used for Locust runner tool. Must have storage.admin access to output_bucket"                                                                              | `string`                                                                                                                                                                                                    | `"sample-runner-ksa"`          |    no    |
| <a name="input_output_bucket"></a> [output\_bucket](#output\_bucket)                                                                          | "Bucket name for storing results"                                                                              | `string`                                                                                                                                                                                                    | n/a          |    yes    |
| <a name="input_max_num_prompts"></a> [max\_num\_prompts](#input\_max\_num\_prompts)                                  | Benchmark server configuration for max number of prompts.                                                                   | `number`                                                                                                                                                                                                    | `1000`               |    no    |
| <a name="input_max_output_len"></a> [max\_output\_len](#input\_max\_output\_len)                                     | Benchmark server configuration for max output length.                                                                       | `number`                                                                                                                                                                                                    | `1024`               |    no    |
| <a name="input_max_prompt_len"></a> [max\_prompt\_len](#input\_max\_prompt\_len)                                     | Benchmark server configuration for max prompt length.                                                                       | `number`                                                                                                                                                                                                    | `1024`               |    no    |
| <a name="input_num_locust_workers"></a> [num\_locust\_workers](#input\num\_locust\_workers)                          | Number of locust worker pods to deploy.                                                                                     | `number`                                                                                                                                                                                                    | `1`                  |    no    |
| <a name="input_namespace"></a> [namespace](#input\_namespace)                                                        | Namespace used for model and benchmarking deployments.                                                                      | `string`                                                                                                                                                                                                    | `"default"`          |    no    |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id)                                                      | Project id of existing or created project.                                           | `string` | n/a                  |   yes    |
| <a name="input_sax_model"></a> [sax\_model](#input\_sax\_model)                                                      | Benchmark server configuration for sax model. Only required if framework is sax.                                            | `string`                                                                                                                                                                                                    | `""`                 |    no    |
| <a name="input_tokenizer"></a> [tokenizer](#input\_tokenizer)                                                        | Benchmark server configuration for tokenizer.                                                                               | `string`                                                                                                                                                                                                    | `"tiiuae/falcon-7b"` |   yes    |
| <a name="input_use_beam_search"></a> [use\_beam\_search](#input\_use\_beam\_search)                                  | Benchmark server configuration for use beam search.                                                                         | `bool`                                                                                                                                                                                                      | `false`              |    no    |
  <a name="huggingface_secret"></a> [huggingface_secret](#input\_huggingface_secret)                                  | Name of the kubectl huggingface secret token                                                                          | `string`                                                                                                                                                                                                      | `huggingface-secret`              |    no   |
<!-- END_TF_DOCS -->
