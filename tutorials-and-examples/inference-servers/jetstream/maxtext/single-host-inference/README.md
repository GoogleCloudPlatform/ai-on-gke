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

In this example, we will deploy a Maxengine server targeting Gemma-7b model. You can use the provided Maxengine server and HTTP server images already in `deployment.yaml` or [build your own](#optionals).

Add desired overrides to your yaml file by editing the `args` in `deployment.yaml`. You can reference the [MaxText base config file](https://github.com/google/maxtext/blob/main/MaxText/configs/base.yml) on what values can be overridden.

In the manifest, ensure the value of the BUCKET_NAME is the name of the Cloud Storage bucket that was used when converting your checkpoint.

Argument descriptions:
```
tokenizer_path: The file path to your model’s tokenizer
load_parameters_path: Your checkpoint path (GSBucket)
per_device_batch_size: Decoding batch size per device (1 TPU chip = 1 device)
max_prefill_predict_length: Maximum length for the prefill when doing autoregression
max_target_length: Maximum sequence length
model_name: Model name
ici_fsdp_parallelism: The number of shards for FSDP parallelism
ici_autoregressive_parallelism: The number of shards for autoregressive parallelism
ici_tensor_parallelism: The number of shards for tensor parallelism
weight_dtype: Weight data type (e.g. bfloat16)
scan_layers: Scan layers boolean flag
```

Deploy the manifest file for the Maxengine server and HTTP server:
```
kubectl apply -f deployment.yaml
```

## Verify the deployment

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

## (optional) Enable Horizontal Pod Autoscaling

TODO: 
Deploy jetstream with above, deploy (podMonitor, CMSA, HPA) without terraform, FIGURE THIS OUT

For instructions on deploying components for handling metrics monitoring via Google Cloud Monitoring and autoscaling via terraform, see the readme in `./terraform`.
Note that the terraform config applied from following that readme will only apply one HPA resource. For those who want to scale based on multiple metrics, we reccomend using the following template:

```
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: jetstream-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: maxengine-server
  minReplicas: <YOUR_MIN_REPLICAS>
  maxReplicas: <YOUR_MAX_REPLICAS>
  metrics:
  - type: Pods
    pods:
      metric:
        name: prometheus.googleapis.com|<YOUR_METRIC_NAME>|gauge
      target:
        type: AverageValue
        averageValue: <YOUR_VALUE_HERE>
```

Next, do the following:
```
gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member=serviceAccount:cmsa-sa@${PROJECT_NAME}.iam.gserviceaccount.com --role=roles/monitoring.viewer --role=roles/monitoring.metricWriter --role=roles/iam.serviceAccountTokenCreator --role=roles/storage.admin --role=roles/storage.objectAdmin

gcloud iam service-accounts add-iam-policy-binding --role roles/iam.workloadIdentityUser --member "serviceAccount:${PROJECT_NAME}.svc.id.goog[custom-metrics/custom-metrics-stackdriver-adapter]" cmsa-sa@${PROJECT_NAME}.iam.gserviceaccount.com
```

 More info about the kubernetes HPA can be found [here](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/).

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

### Interact with the Maxengine server directly using gRPC

The Jetstream HTTP server is great for initial testing and validating end-to-end requests and responses. If you would like to interact directly with the Maxengine server directly for use cases such as [benchmarking](https://github.com/google/JetStream/tree/main/benchmarks), you can do so by following the Jetstream benchmarking setup and applying the `deployment.yaml` manifest file and interacting with the Jetstream gRPC server at port 9000.

```
kubectl apply -f deployment.yaml

kubectl port-forward svc/jetstream-svc 9000:9000
```

To run benchmarking, pass in the flag `--server 127.0.0.1` when running the benchmarking script.