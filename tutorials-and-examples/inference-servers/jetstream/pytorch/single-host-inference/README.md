# Serve a LLM using a single-host TPU on GKE with JetStream and PyTorch/XLA

## Background
This tutorial shows you how to serve a large language model (LLM) using Tensor Processing Units (TPUs) on Google Kubernetes Engine (GKE) with [JetStream](https://github.com/google/JetStream) and [Jetstream-Pytorch](https://github.com/google/jetstream-pytorch).

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
    --addons GcsFuseCsiDriver
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

### Create a Cloud Storage bucket to store the Llama2-7b model checkpoint

```
BUCKET_NAME=<your desired gsbucket name>
gcloud storage buckets create $BUCKET_NAME
```

## Checkpoint conversion
Follow the instructions here to download the llama-2-7b weights: https://github.com/meta-llama/llama#download 

Upload your weights to your GSBucket

```
gcloud storage cp -r <directory where weights are stored>/* gs://BUCKET_NAME/llama-2-7b/base/
```

Run the checkpoint conversion job. This will use the [checkpoint conversion script](https://github.com/google/jetstream-pytorch/blob/main/convert_checkpoints.py) from Jetstream-pytorch to create a compatible Pytorch checkpoint

Please make sure you edit `checkpoint-job` and replace all occurrences of `BUCKET_NAME` with the `BUCKET_NAME` that you have set above.

```
kubectl apply -f checkpoint-job.yaml
```

Observe your checkpoint
```
kubectl logs -f jobs/checkpoint-converter
# This can take several minutes
...
Completed uploading converted checkpoint from local path /pt-ckpt/ to GSBucket gs://BUCKET_NAME/pytorch/llama2-7b/final/bf16/"
```

Now your converted checkpoint will be located in `gs://BUCKET_NAME/pytorch/llama2-7b/final/bf16/`

## Deploy the Jetstream Pytorch server

The following flags are set in the manifest file
```
--param_size: Size of model
--batch_size: Batch size
--max_cache_length: Maximum length of kv cache 
--platform=tpu: TPU machine type (8 for v5e-8, 4 for v4-8)
--tokenizer_path: Path to model tokenizer file
--checkpoint_path: Path to checkpoint
Optional flags to add
--quantize_weights (Default False): Checkpoint is quantized
--quantize_kv_cache (Default False): Quantized kv cache
```

```
kubectl apply -f deployment.yaml
```

### Verify the deployment
```
kubectl get deployment
NAME               		READY   UP-TO-DATE   AVAILABLE   AGE
jetstream-pytorch-server   2/2     2            2           ##s
```

View the HTTP server logs to check that the model has been loaded and compiled. It may take the server a few minutes to complete this operation.

```
kubectl logs deploy/jetstream-pytorch-server -f -c jetstream-http
INFO:     Started server process [1]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

View the Jetstream Pytorch server logs and verify that the compilation is done.

```
kubectl logs deploy/jetstream-pytorch-server -f -c jetstream-pytorch-server
Started jetstream_server....
2024-04-12 04:33:37,128 - root - INFO - ---------Generate params 0 loaded.---------
```

## Serve the model

```
kubectl port-forward svc/jetstream-svc 8000:8000
```

Interact with the model via curl

```
curl --request POST \
--header "Content-type: application/json" \
-s \
localhost:8000/generate \
--data \
'{
    "prompt": "What are the top 5 programming languages",
    "max_tokens": 200
}'
```

The initial request can take several seconds to complete due to model warmup. The output is similar to the following:

```
{
    "response": " for 2019?\nWhat are the top 5 programming languages for 2019? The top 5 programming languages for 2019 are Python, Java, JavaScript, C, and C++.\nWhat are the top 5 programming languages for 2019? The top 5 programming languages for 2019 are Python, Java, JavaScript, C, and C++. These languages are used in a variety of industries and are popular among developers.\nPython is a versatile language that can be used for web development, data analysis, and machine learning. It is easy to learn and has a large community of developers.\nJava is a popular language for enterprise applications and is used by many large companies. It is also used for mobile development and has a large community of developers.\nJavaScript is a popular language for web development and is used by many websites. It is also used for mobile development and has a"
}
```

## Optionals

### Interact with the Jetstream Pytorch server directly using gRPC

The Jetstream HTTP server is great for initial testing and validating end-to-end requests and responses. In production use case, it's recommended to interact with the JetStream-Pytorch server directly for better throughput/latency and use the streaming decode feature on the JetStream grpc server.

```
kubectl port-forward svc/jetstream-svc 9000:9000
```
Now you can interact with the JetStream grpc server directly via port 9000.

### Use a Persistent Disk to host your checkpoint

Create a GCE CPU VM to do your checkpoint conversion. 

```
gcloud compute instances create jetstream-ckpt-converter \
  --zone=us-central1-a \
  --machine-type=n2-standard-32 \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --image=projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20230919 \
  --boot-disk-size=128GB \
  --boot-disk-type=pd-balanced
```

SSH into the VM and install python and git
```
gcloud compute ssh jetstream-ckpt-converter --zone=us-central1-a
sudo apt update
sudo apt-get install python3-pip
sudo apt-get install git-all
```

In your CPU VM, follow these instructions to do the following:
1. Clone the jetstream-pytorch repository
2. Run the installation script
3. Download and convert llama-2-7b weights

After running weight safetensor convert, you should see the following files in the directory you have saved them to:

```
ls <directory where checkpoint is stored>
model.safetensors  params.json
```

Create a persistent disk to store your checkpoint
```
gcloud compute disks create jetstream-pytorch-ckpt --zone=us-west4-a --type pd-balanced
NAME                    ZONE        SIZE_GB  TYPE         STATUS
pytorch-jetstream-ckpt  us-west4-a  100      pd-balanced  READY
```

Attach the disk to your VM
```
gcloud compute instances attach-disk jetstream-ckpt-converter \
  --disk jetstream-pytorch-ckpt --project $PROJECT_ID --zone us-west4-a
```

Identity your disk, it will be similar to the following but may also have a different name:

```
lsblk
NAME    MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
...
sdc       8:32   0   100G  0 disk 
```

Format your disk and create a directory in its mount folder

```
sudo mkfs.ext4 /dev/sdc
mkdir /mnt/jetstream-pytorch-ckpt
sudo mount /dev/sdc /mnt/jetstream-pytorch-ckpt
```

Copy your converted checkpoint folder into /mnt/jetstream-pytorch-ckpt
```
cp <path to converterted checkpoint> /mnt/jetstream-pytorch-ckpt
```

Unmount and detach your persistent disk
```
sudo umount /mnt/jetstream-pytorch-ckpt
gcloud compute instances detach-disk jetstream-ckpt-converter \
  --disk jetstream-pytorch-ckpt --project $PROJECT_ID --zone us-west4-a
```

Apply your storage and deployment manifest file
```
kubectl apply -f storage.yaml
kubectl apply -f pd-deployment.yaml
```