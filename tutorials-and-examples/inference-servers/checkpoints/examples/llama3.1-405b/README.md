# Checkpoint conversion with Llama3.1-405B

This example will walk through converting a Llama3.1-405b from Meta to a MaxText compatible checkpoint for inference.

The Llama3-405B model needs ~2000 GB of client memory to download and run checkpoint conversion. This machine type and boot disk size will ensure enough capacity to facilitate the model download and conversion. The checkpoint conversion for the 405B model supports weights downloaded only from Meta.

## Agree to the Meta Terms and Conditions
Go to https://www.llama.com/llama-downloads/ to acknowledge the terms and conditions. Select `Llama3.1: 405B & 8B` as the model(s) you will request.

Copy the provided Meta URL to use in your manifest file.

## Create GCS Bucket to store checkpoint
```
BUCKET_NAME=<your bucket>

gcloud storage buckets create gs://$BUCKET_NAME
```

## Configure a service account for Storage Object access
**This step can be skipped if already done on the cluster with a different Service Account.**

Configure a Kubernetes service account to act as an IAM service account.

Create an IAM service account for your application:

```
gcloud iam service-accounts create checkpoint-converter
```

Add an IAM policy binding for your IAM service account to manage Cloud Storage:

```
gcloud projects add-iam-policy-binding ${PROJECT} \
  --member "serviceAccount:checkpoint-converter@${PROJECT}.iam.gserviceaccount.com" \
  --role roles/storage.objectUser

gcloud projects add-iam-policy-binding ${PROJECT} \
  --member "serviceAccount:checkpoint-converter@${PROJECT}.iam.gserviceaccount.com" \
  --role roles/storage.insightsCollectorService
```

Annotate the Kubernetes service account with the email address of the IAM service account. 

```
kubectl annotate serviceaccount default \
iam.gke.io/gcp-service-account=checkpoint-converter@${PROJECT}.iam.gserviceaccount.com
```

## Provision resources to facilitate conversion
Create a node pool with machine type `m1-ultramem-160`. You may need to request m1 quota in your project.

```
CLUSTER=<your cluster>
ZONE=<your zone>
PROJECT=<project>

gcloud container node-pools create m1-pool \
--cluster "${CLUSTER}" \
--zone "${ZONE}" \
--machine-type m1-ultramem-160 \
--num-nodes 1 \
--disk-size 3000 \
--project "${PROJECT}" \
--scopes cloud-platform
```

In `checkpoint-converter.yaml`, replace `BUCKET_NAME` with the GCS Bucket that you created earlier, without gs://.

Parameter descriptions:

```
--bucket_name: [string] The GSBucket name to store checkpoints, without gs://.
--inference_server: [string] The name of the inference server that serves your model. (ex. jetstream-maxtext)
--meta_url: [string] The url from Meta.
--model_name: [string] The model name. (ex. llama-2, llama-3, llama-3.1)
--model_path: [string] The model path. For Llama models, download llama via `pip install llama-stack` and run `llama model list --show-all` for Model Descriptor to use. (ex. Llama3.1-405B-Instruct:bf16-mp16)
--output_directory: [string] The output directory. (ex. gs://bucket_name/maxtext/llama3.1-405b)
--quantize_type: [string] The type of quantization. (ex. int8)
--quantize_weights: [bool] The checkpoint is to be quantized. (ex. True)
```

For a bf16 checkpoint only, remove the flags `--quantize_type` and `--quantize_weights`.

Apply the manifest:

```
kubectl apply -f checkpoint-converter.yaml
```

The checkpoint conversion job takes around 9-10 hours to complete, To monitor the progress of the checkpoint download and conversion, check [GCP Log Explorer](https://console.cloud.google.com/logs/query) and enter the following query:

```
resource.type="k8s_container"
resource.labels.project_id="PROJECT_ID"
resource.labels.location="LOCATION"
resource.labels.cluster_name="CLUSTER_NAME"
resource.labels.namespace_name="default"
resource.labels.pod_name:"checkpoint-converter-"
```

Once completed, you will see a log similar to:

```
# bf16 checkpoint
Completed unscanning checkpoint to gs://output_directory/bf16/unscanned/checkpoints/0/items

# int8 checkpoint
Completed quantizing model llama3.1-405b with int8 to gs://output_directory/int8
```

