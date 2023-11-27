# Serve a LLM using a single-host TPU on GKE with Saxml 

## Background

This tutorial shows you how to serve a large language model (LLM) using Tensor Processing Units (TPUs) on Google Kubernetes Engine (GKE) with [Saxml](https://github.com/google/saxml#saxml-aka-sax). Saxml is an experimental system that serves [Paxml](https://github.com/google/paxml), [JAX](https://github.com/google/jax), and [PyTorch](https://pytorch.org/) models for inference. The model you use in this guide is the [GPT-J model](https://github.com/mlcommons/inference/blob/master/language/gpt-j/README.md#download-gpt-j-model).

Single-host model serving is applicable to single-host TPU slice, that is, v5litepod-1, v5litepod-4 and v5litepod-8. You can learn more about [TPUs in GKE](https://cloud.devsite.corp.google.com/kubernetes-engine/docs/concepts/tpus). 

Single-host model serving is applicable to single-host TPU slice as demonstrated in this [user guide](https://cloud.google.com/tpu/docs/v5e-inference#single-host-example). This tutorial walks you through single-host model serving on GKE using the GPT-J 6B model and Saxml.


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
gcloud container clusters create saxml \
    --zone=${ZONE} \
    --project=${PROJECT_ID} \
    --workload-pool=${PROJECT_ID}.svc.id.goog \
    --release-channel=rapid \
    --num-nodes=2 \

# Create one v5e TPU pool with topology 2x2 (1 TPU node with 4 chips)
gcloud container node-pools create tpu \
    --cluster=saxml \
    --zone=${ZONE} \
    --num-nodes=1 \
    --machine-type=ct5lp-hightpu-4t \
    --project=${PROJECT_ID} \
```

You have created the following resources:
- Standard cluster with 2 CPU nodes.
- One v5e TPU node pool with 4 chips.

### Configure Applications to use Workload Identity
Prequisite: make sure you have the following roles

```
roles/container.admin
roles/iam.serviceAccountAdmin
```

Follow [these steps](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#authenticating_to) to configure the IAM and Kubernetes service account:

```
# Get credentials for your cluster
$ gcloud container clusters get-credentials saxml \
    --region=${REGION}

# Create a k8s service account.
$ kubectl create serviceaccount sax-sa --namespace default

# Create an IAM service account.
$ gcloud iam service-accounts create sax-iam-sa

# Ensure the IAM service account has necessary roles. Here we add roles/storage.admin for gcs bucket access.
$ gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member "serviceAccount:sax-iam-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/storage.admin

# Allow the Kubernetes service account to impersonate the IAM service account
$ gcloud iam service-accounts add-iam-policy-binding sax-iam-sa@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[default/sax-sa]"

# Annotate the Kubernetes service account with the email address of the IAM service account.
$ kubectl annotate serviceaccount sax-sa \
    iam.gke.io/gcp-service-account=sax-iam-sa@${PROJECT_ID}.iam.gserviceaccount.com
```

### Create a Cloud Storage Bucket used by Saxml

Create a Cloud Storage bucket to store Sax admin server configurations. A running admin server will periodically save its state, including details of published models. Its network address will also be saved here and is the target address that newly started model servers will try to join. 

```
SAX_ADMIN_STORAGE_BUCKET=[BUCKET_NAME]
gcloud storage buckets create gs://${SAX_ADMIN_STORAGE_BUCKET}
```

### Build and upload HTTP Server image

In `admin-server.yaml`, `model-server.yaml`, and `http-server.yaml`, replace the following:

- `${SAX_ADMIN_STORAGE_BUCKET}` with `[BUCKET_NAME]`

Note: You can use your own HTTP server built for Saxml. To learn more, see [Inferencing using Saxml and an HTTP Server](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/main/saxml-on-gke/httpserver).

## Deploy Saxml Admin Server, Model Server, and HTTP server

Deploy the following manifest files for the Saxml admin server, Saxml model server, HTTP server, and loadbalancer.

```
kubectl apply -f admin-server.yaml
kubectl apply -f model-server.yaml
kubectl apply -f http-server.yaml
kubectl apply -f load-balancer.yaml
```

## Convert Checkpoint for Model

Convert the GPT-J checkpoint from EleutherAI to Pax

### Create a GCE CPU VM
The model checkpoint is around 21GB of memory, and the conversion script consumes around 100GB of memory, so we recommend using n2-standard-32 machine type which has around 128GB of memory. `python3.10` is also needed to install paxml, so we recommend using Ubuntu.

```
gcloud compute instances create gptj-ckpt-converter \
  --zone=us-central1-a \
  --machine-type=n2-standard-32 \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --image=projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20230919 \
  --boot-disk-size=128GB \
  --boot-disk-type=pd-balanced
```

### Install Dependencies
```
gcloud compute ssh gptj-ckpt-converter --zone=us-central1-a

sudo apt update
sudo apt-get install python3-pip
sudo apt-get install git-all

pip3 install accelerate
pip3 install torch
pip3 install transformers

pip3 install paxml==1.1.0
pip3 install jaxlib==0.4.14
```

### Download the finetuned GPTJ-6B Model

```
$ PT_CHECKPOINT_PATH=./fine_tuned_pt_checkpoint
```

Follow the directions from here https://github.com/mlcommons/inference/blob/master/language/gpt-j/README.md#download-gpt-j-model to download the GPT-J model.

```
$ ls ${PT_CHECKPOINT_PATH}
README.md          generation_config.json            pytorch_model-00002-of-00003.bin  special_tokens_map.json  vocab.json
added_tokens.json  merges.txt                        pytorch_model-00003-of-00003.bin  tokenizer_config.json
config.json        pytorch_model-00001-of-00003.bin  pytorch_model.bin.index.json      trainer_state.json
```


### Convert checkpoint
Get the conversion script to convert the GPT-J checkpoint to SAX checkpoint

```
wget https://raw.githubusercontent.com/google/saxml/main/saxml/tools/convert_gptj_ckpt.py
```

Convert the weights from downloaded model to pax

```
$ ls
convert_gptj_ckpt.py  fine_tuned_pt_checkpoint

$ python3 -m convert_gptj_ckpt --base ${PT_CHECKPOINT_PATH} --pax pax_6b

# This should generate content similar to the following: 
transformer.wte.weight (50401, 4096)
transformer.h.0.ln_1.weight (4096,)
transformer.h.0.ln_1.bias (4096,)
transformer.h.0.attn.k_proj.weight (4096, 4096)
.
.
.
transformer.ln_f.weight (4096,)
transformer.ln_f.bias (4096,)
lm_head.weight (50401, 4096)
lm_head.bias (50401,)
Saving the pax model to .
done

$ ls
convert_gptj_ckpt.py  fine_tuned_pt_checkpoint  pax_6b
```
### Copy checkpoint to GSBucket
Create another Cloud Storage bucket to store the checkpoint

```
SAX_DATA_STORAGE_BUCKET=[BUCKET_NAME]
gcloud storage buckets create gs://${SAX_DATA_STORAGE_BUCKET}
```

```
$ cd pax_6b
$ ls checkpoint_00000000/
metadata  state

$ GS_CHECKPOINT_PATH=gs://${SAX_DATA_STORAGE_BUCKET}/path/to/checkpoint_00000000
$ gsutil -m cp -r checkpoint_00000000 ${GS_CHECKPOINT_PATH}
$ touch commit_success.txt
$ gsutil cp commit_success.txt ${GS_CHECKPOINT_PATH}/
$ gsutil cp commit_success.txt ${GS_CHECKPOINT_PATH}/metadata/
$ gsutil cp commit_success.txt ${GS_CHECKPOINT_PATH}/state/
```

## Use Saxml

```
$ kubectl get svc
NAME          TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                                        AGE
sax-http-lb   LoadBalancer   10.16.14.175   10.142.0.68   8888:30191/TCP                                 3h36m
```

You will be able to use the EXTERNAL_IP, such as 10.142.0.68 and port 8888 to send requests to the HTTP Server.

```
$ LB_IP=$(kubectl get svc sax-http-lb -o jsonpath='{.status.loadBalancer.ingress[*].ip}')
$ PORT="8888"
```
### Publish GPT-J 6B Model

Replace `${SAX_DATA_STORAGE_BUCKET}` below with your bucket name

```
$ curl --request POST \
--header "Content-type: application/json" \
-s \
${LB_IP}:${PORT}/publish \
--data '
{
    "model": "/sax/test/gptj4bf16bs32",
    "model_path": "saxml.server.pax.lm.params.gptj.GPTJ4BF16BS32",
    "checkpoint": "gs://${SAX_DATA_STORAGE_BUCKET}/checkpoints/checkpoint_00000000",
    "replicas": "1"
}
'

# Response
{
    "model": "/sax/test/gptj4bf16bs32",
    "model_path": "saxml.server.pax.lm.params.gptj.GPTJ4BF16BS32",
    "checkpoint": "gs://${SAX_DATA_STORAGE_BUCKET}/checkpoints/checkpoint_00000000",
    "replicas": "1"
}
```

Check Model Server to ensure model has been loaded

```
$ kubectl get pods
NAME                                READY   STATUS    RESTARTS   AGE
sax-admin-server-5bfc75866f-4dkqv   1/1     Running   0          5d20h
sax-http-6444cb787f-trkdw           1/1     Running   0          5d18h
sax-model-server-bfb999969-h742s    1/1     Running   0          6m48s

$ kubectl logs sax-model-server-bfb999969-h742s

...
W0905 22:09:39.180598 136507323041344 dispatch.py:254] Finished jaxpr to MLIR module conversion pjit(_wrapped_fn) in 1.5629382133483887 sec
W0905 22:09:52.780057 136507323041344 dispatch.py:254] Finished XLA compilation of pjit(_wrapped_fn) in 13.598859310150146 sec
I0905 22:09:56.715947 136507323041344 servable_model.py:697] loading completed.
```
### Generate a summary
```
json_payload=$(cat  << EOF
{ 
  "model": "/sax/test/gptj4bf16bs32", 
  "query": "Below is an instruction that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.\n\n### Instruction:\nSummarize the following news article:\n\n### Input:\nMarch 10, 2015 . We're truly international in scope on Tuesday. We're visiting Italy, Russia, the United Arab Emirates, and the Himalayan Mountains. Find out who's attempting to circumnavigate the globe in a plane powered partially by the sun, and explore the mysterious appearance of craters in northern Asia. You'll also get a view of Mount Everest that was previously reserved for climbers. On this page you will find today's show Transcript and a place for you to request to be on the CNN Student News Roll Call. TRANSCRIPT . Click here to access the transcript of today's CNN Student News program. Please note that there may be a delay between the time when the video is available and when the transcript is published. CNN Student News is created by a team of journalists who consider the Common Core State Standards, national standards in different subject areas, and state standards when producing the show. ROLL CALL . For a chance to be mentioned on the next CNN Student News, comment on the bottom of this page with your school name, mascot, city and state. We will be selecting schools from the comments of the previous show. You must be a teacher or a student age 13 or older to request a mention on the CNN Student News Roll Call! Thank you for using CNN Student News!\n\n### Response:"
}
EOF
)

curl --request POST \
--header "Content-type: application/json" \
-s \
${LB_IP}:${PORT}/generate \
--data "$json_payload"

# Response
{
    "generate_response": [
        [
            "This page includes the show Transcript.\nUse the Transcript to help students with reading comprehension and vocabulary.\nAt the bottom of the page, comment for a chance to be mentioned on CNN Student News.  You must be a teacher or a student age 13 or older to request a mention on the CNN Student News Roll Call.",
            -0.0309655349701643
        ],
        [
            "This page includes the show Transcript.\nUse the Transcript to help students with reading comprehension and vocabulary.\nAt the bottom of the page, comment for a chance to be mentioned on CNN Student News.  You must be a teacher or a student age 13 or older to request a mention on the CNN Student News Roll Call!",
            -0.8270811438560486
        ],
        [
            "This page includes the show Transcript.\nUse the Transcript to help students with reading comprehension and vocabulary.\nAt the bottom of the page, comment for a chance to be mentioned on CNN Student News. You must be a teacher or a student age 13 or older to request a mention on the CNN Student News Roll Call.",
            -1.0186288356781006
        ],
        [
            "This page includes the show Transcript.\nUse the Transcript to help students with reading comprehension and vocabulary.\nAt the bottom of the page, comment for a chance to be mentioned on CNN Student News.  You must be a teacher or a student age 13 or older to request a mention on the CNN Student News Roll Call.\nThe weekly Newsquiz tests students' knowledge of events in the news.",
            -1.3383952379226685
        ]
    ]
}
```
### Unpublish model
```
curl --request POST \
--header "Content-type: application/json" \
-s \
${LB_IP}:${PORT}/unpublish \
--data '
{
    "model": "/sax/test/gptj4bf16bs32"
}
'

# Response
{
    "model": "/sax/test/gptj4bf16bs32"
}
```
## Clean Up
```
gcloud container clusters delete saxml --zone=${ZONE}
gcloud compute instances delete gptj-ckpt-converter
gcloud iam service-accounts delete sax-iam-sa@${PROJECT_ID}.iam.gserviceaccount.com
gcloud storage rm --recursive gs://${SAX_ADMIN_STORAGE_BUCKET}
gcloud storage rm --recursive gs://${SAX_DATA_STORAGE_BUCKET}
```

## Next up
Learn to [scale your application](https://cloud.google.com/kubernetes-engine/docs/how-to/scaling-apps).