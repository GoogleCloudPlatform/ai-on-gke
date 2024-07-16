# Serve a LLM using a single-host TPU on GKE with JetStream and MaxText

## Background
This tutorial shows you how to serve a large language model (LLM) using Tensor Processing Units (TPUs) on Google Kubernetes Engine (GKE) with [JetStream](https://github.com/google/JetStream) and [MaxText](https://github.com/google/maxtext). 

## Setup

### Set default environment variables
```
gcloud config set project [PROJECT_ID]
export PROJECT_ID=$(gcloud config get project)
export REGION=[COMPUTE_REGION]
export ZONE=[ZONE]
```

### Create GKE cluster and node pool
```
# Create zonal cluster with 2 CPU nodes
gcloud container clusters create jetstream-maxtext \
    --zone=${ZONE} \
    --project=${PROJECT_ID} \
    --workload-pool=${PROJECT_ID}.svc.id.goog \
    --release-channel=rapid \
    --num-nodes=2

# Create one v5e TPU pool with topology 2x4 (1 TPU node with 8 chips)
gcloud container node-pools create tpu \
    --cluster=jetstream-maxtext \
    --zone=${ZONE} \
    --num-nodes=2 \
    --machine-type=ct5lp-hightpu-8t \
    --project=${PROJECT_ID}
```
You have created the following resources:

- Standard cluster with 2 CPU nodes.
- One v5e TPU node pool with 2 nodes, each with 8 chips.

### Configure Applications to use Workload Identity
Prerequisite: make sure you have the following roles

```
roles/container.admin
roles/iam.serviceAccountAdmin
```

Follow [these steps](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#authenticating_to) to configure the IAM and Kubernetes service account:

```
# Get credentials for your cluster
$ gcloud container clusters get-credentials jetstream-maxtext \
    --zone=${ZONE}

# Create an IAM service account.
$ gcloud iam service-accounts create jetstream-iam-sa

# Ensure the IAM service account has necessary roles. Here we add roles/storage.objectUser for gcs bucket access.
$ gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member "serviceAccount:jetstream-iam-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/storage.objectUser

$ gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member "serviceAccount:jetstream-iam-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/storage.insightsCollectorService

# Allow the Kubernetes default service account to impersonate the IAM service account
$ gcloud iam service-accounts add-iam-policy-binding jetstream-iam-sa@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[default/default]"

# Annotate the Kubernetes service account with the email address of the IAM service account.
$ kubectl annotate serviceaccount default \
    iam.gke.io/gcp-service-account=jetstream-iam-sa@${PROJECT_ID}.iam.gserviceaccount.com
```

### Create a Cloud Storage bucket to store the Gemma-7b model checkpoint

```
gcloud storage buckets create $BUCKET_NAME
```

### Get access to the model

Access the [model consent page](https://www.kaggle.com/models/google/gemma) and request access with your Kaggle Account. Accept the Terms and Conditions. 

Obtain a Kaggle API token by going to your Kaggle settings and under the `API` section, click `Create New Token`. A `kaggle.json` file will be downloaded.

Create a Secret to store the Kaggle credentials
```
kubectl create secret generic kaggle-secret \
    --from-file=kaggle.json
```

## Convert the Gemma-7b checkpoint

To convert the Gemma-7b checkpoint, we have created a job `checkpoint-job.yaml` that does the following:
1. Download the base orbax checkpoint from kaggle
2. Upload the checkpoint to a Cloud Storage bucket
3. Convert the checkpoint to a MaxText compatible checkpoint
4. Unscan the checkpoint to be used for inference

In the manifest, ensure the value of the BUCKET_NAME environment variable is the name of the Cloud Storage bucket you created above. Do not include the `gs://` prefix.

Apply the manifest:
```
kubectl apply -f checkpoint-job.yaml
```

Observe the logs:
```
kubectl logs -f jobs/data-loader-7b
```

You should see the following output once the job has completed. This will take around 10 minutes:
```
Successfully generated decode checkpoint at: gs://BUCKET_NAME/final/unscanned/gemma_7b-it/0/checkpoints/0/items
+ echo -e '\nCompleted unscanning checkpoint to gs://BUCKET_NAME/final/unscanned/gemma_7b-it/0/checkpoints/0/items'

Completed unscanning checkpoint to gs://BUCKET_NAME/final/unscanned/gemma_7b-it/0/checkpoints/0/items
```

## Deploy Maxengine Server and HTTP Server

Next, deploy a Maxengine server hosting the Gemma-7b model. You can use the provided Maxengine server and HTTP server images or [build your own](#build-and-upload-maxengine-server-image). Depending on your needs and constraints you can elect to deploy either via Terraform or via Kubectl.

### Deploy via Kubectl

See the [Jetstream component README](../../../../../modules/jetstream-maxtext-deployment/README.md#installation-via-bash-and-kubectl) for start to finish instructions on how to deploy jetstream to your cluster, assure the value of the PARAMETERS_PATH is the path where the checkpoint-converter job uploaded the converted checkpoints to, in this case it should be `gs://$BUCKET_NAME/final/unscanned/gemma_7b-it/0/checkpoints/0/items` where $BUCKET_NAME is the same as above.

 This README also includes [instructions for setting up autoscaling](../../../../../modules//jetstream-maxtext-deployment/README.md#optional-autoscaling-components). Follow those instructions to install the required components for autoscaling and configuring your HPAs appropriately.

### Deploy via Terraform

Navigate to the `./terraform` directory and run [`terraform init`](https://developer.hashicorp.com/terraform/cli/commands/init). The deployment requires some inputs, an example `sample-terraform.tfvars` is provided as a starting point, run `cp sample-terraform.tfvars terraform.tfvars` and modify the resulting `terraform.tfvars` as needed. Since we're using gemma-7b the `maxengine_deployment_settings.parameters_path` terraform variable should be set to the following: `gs://BUCKET_NAME/final/unscanned/gemma_7b-it/0/checkpoints/0/items`. Finally run `terraform apply` to apply these resources to your cluster.

For deploying autoscaling components via terraform, a few more variables to be set, doing so and rerunning the [prior step](#deploy-via-terraform) with these set will deploy the components. The following variables should be set:

```
maxengine_deployment_settings = {
  metrics_port = <same as above>
  metrics_scrape_interval
}

hpa_config = {
  metrics_adapter = <either 'prometheus-adapter` (recommended) or 'custom-metrics-stackdriver-adapter' >
  max_replicas
  min_replicas
  rules = [{
    target_query = <see [jetstream-maxtext-module README](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/main/modules//jetstream-maxtext-deployment/README.md) for a list of valid values>
    average_value_target
  }]
}
```

### Verify the deployment

Wait for the containers to finish creating:
```
kubectl get deployment

NAME               READY   UP-TO-DATE   AVAILABLE   AGE
maxengine-server   2/2     2            2           ##s
```

Check the Maxengine pod’s logs, and verify the compilation is done. You will see similar logs of the following:
```
kubectl logs deploy/maxengine-server -f -c maxengine-server

2024-03-29 17:09:08,047 - jax._src.dispatch - DEBUG - Finished XLA compilation of jit(initialize) in 0.26236414909362793 sec
2024-03-29 17:09:08,150 - root - INFO - ---------Generate params 0 loaded.---------
```

Check http server logs, this can take a couple minutes:
```
kubectl logs deploy/maxengine-server -f -c jetstream-http

INFO:     Started server process [1]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

### Send sample requests

Run the following command to set up port forwarding to the http server:

```
kubectl port-forward svc/jetstream-svc 8000:8000
```

In a new terminal, send a request to the server:

```
curl --request POST --header "Content-type: application/json" -s localhost:8000/generate --data '{
    "prompt": "What are the top 5 programming languages",
    "max_tokens": 200
}'
```

The output should be similar to the following:
```
{
    "response": " in 2021?\n\nThe answer to this question is not as simple as it may seem. There are many factors that go into determining the most popular programming languages, and they can change from year to year.\n\nIn this blog post, we will discuss the top 5 programming languages in 2021 and why they are so popular.\n\n<h2><strong>1. Python</strong></h2>\n\nPython is a high-level programming language that is used for web development, data analysis, and machine learning. It is one of the most popular languages in the world and is used by many companies such as Google, Facebook, and Instagram.\n\nPython is easy to learn and has a large community of developers who are always willing to help out.\n\n<h2><strong>2. Java</strong></h2>\n\nJava is a general-purpose programming language that is used for web development, mobile development, and game development. It is one of the most popular languages in the"
}
```

## Other optional steps
### Build and upload Maxengine Server image

Build the Maxengine Server from [here](../maxengine-server) and upload to your project
```
docker build -t maxengine-server .
docker tag maxengine-server gcr.io/${PROJECT_ID}/jetstream/maxtext/maxengine-server:latest
docker push gcr.io/${PROJECT_ID}/jetstream/maxtext/maxengine-server:latest
```

### Build and upload HTTP Server image

Build the HTTP Server Dockerfile from [here](../http-server) and upload to your project
```
docker build -t jetstream-http .
docker tag jetstream-http gcr.io/${PROJECT_ID}/jetstream/maxtext/jetstream-http:latest
docker push gcr.io/${PROJECT_ID}/jetstream/maxtext/jetstream-http:latest
```

### Interact with the Maxengine server directly using gRPC

The Jetstream HTTP server is great for initial testing and validating end-to-end requests and responses. If you would like to interact directly with the Maxengine server directly for use cases such as [benchmarking](https://github.com/google/JetStream/tree/main/benchmarks), you can do so by following the Jetstream benchmarking setup and applying the `deployment.yaml` manifest file and interacting with the Jetstream gRPC server at port 9000.

```
kubectl apply -f kubectl/deployment.yaml

kubectl port-forward svc/jetstream-svc 9000:9000
```

To run benchmarking, pass in the flag `--server 127.0.0.1` when running the benchmarking script.

### Observe custom metrics

This step assumes you specified a metrics port to your jetstream deployment via `prometheus_port`. If you would like to probe the metrics manually, `cURL` your maxengine-server container on the metrics port you set and you should see something similar to the following:

```
# HELP jetstream_prefill_backlog_size Size of prefill queue
# TYPE jetstream_prefill_backlog_size gauge
jetstream_prefill_backlog_size{id="SOME-HOSTNAME-HERE>"} 0.0
# HELP jetstream_slots_used_percentage The percentage of decode slots currently being used
# TYPE jetstream_slots_used_percentage gauge
jetstream_slots_used_percentage{id="<SOME-HOSTNAME-HERE>",idx="0"} 0.04166666666666663
```