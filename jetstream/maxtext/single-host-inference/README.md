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

## Convert the Gemma-7b checkpoint

You can follow [these instructions](https://github.com/google/maxtext/blob/main/end_to_end/test_gemma.sh#L14) to convert the Gemma-7b checkpoint from orbax to a MaxText compatible checkpoint.

## Deploy Maxengine Server and HTTP Server

In this example, we will deploy a Maxengine server targeting Gemma-7b model. You can use the provided Maxengine server and HTTP server images already in `deployment.yaml` or [build your own](#optionals).

Add desired overrides to your yaml file by editing the `args` in `deployment.yaml`. You can reference the [MaxText base config file](https://github.com/google/maxtext/blob/main/MaxText/configs/base.yml) on what values can be overridden. 

Configure the model checkpoint by adding `load_parameters_path=<GCS bucket path to your checkpoint>` under `args`, you can optionally deploy `deployment.yaml` without adding the checkpoint path. 

Deploy the manifest file for the Maxengine server and HTTP server:
```
kubectl apply -f deployment.yaml
```

## Verify the deployment

Wait for the containers to finish creating:
```
kubectl get deployment

NAME               READY   UP-TO-DATE   AVAILABLE   AGE
maxengine-server   1/1     1            1           2m45s
```

Check the Maxengine pod’s logs, and verify the compilation is done. You will see similar logs of the following:
```
kubectl logs deploy/maxengine-server -f -c maxengine-server

2024-03-14 06:03:37,750 - jax._src.dispatch - DEBUG - Finished XLA compilation of jit(generate) in 8.170992851257324 sec
2024-03-14 06:03:38,779 - root - INFO - Generate engine 0 step 1 - slots free : 96 / 96, took 11807.21ms
2024-03-14 06:03:38,780 - root - INFO - Generate thread making a decision with: prefill_backlog=0 generate_free_slots=96
2024-03-14 06:03:38,831 - root - INFO - Detokenising generate step 0 took 46.34ms
2024-03-14 06:03:39,793 - root - INFO - Generate engine 0 step 2 - slots free : 96 / 96, took 1013.51ms
2024-03-14 06:03:39,793 - root - INFO - Generate thread making a decision with: prefill_backlog=0 generate_free_slots=96
2024-03-14 06:03:39,797 - root - INFO - Generate engine 0 step 3 - slots free : 96 / 96, took 3.35ms
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
kubectl port-forward svc/jetstream-http-svc 8000:8000
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

## Optionals
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