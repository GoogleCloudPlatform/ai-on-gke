# NVIDIA NIM on GKE Demo

TODO:
* Change node-pool to NOT spot


## Set up your GKE Cluster

Choose your region and set your project:
```bash
export REGION=us-central1
export PROJECT_ID=$(gcloud config get project)
export MACH=g2-standard-48
export GPU_TYPE=nvidia-l4
export GPU_COUNT=4
```

Create a GKE cluster:
```bash
gcloud container clusters create nim-demo --location ${REGION} \
  --workload-pool ${PROJECT_ID}.svc.id.goog \
  --enable-image-streaming \
  --enable-ip-alias \
  --node-locations=$REGION-a \
  --workload-pool=${PROJECT_ID}.svc.id.goog \
  --addons GcsFuseCsiDriver   \
  --machine-type n2d-standard-4 \
  --num-nodes 1 --min-nodes 1 --max-nodes 5 \
  --ephemeral-storage-local-ssd=count=2
```

Create a nodepool where each VM has 2 x L4 GPU:
```bash
gcloud container node-pools create ${MACH}-node-pool --cluster nim-demo \
  --accelerator type=${GPU_TYPE},count=${GPU_COUNT},gpu-driver-version=latest \
  --machine-type ${MACH} \
  --ephemeral-storage-local-ssd=count=${GPU_COUNT} \
  --enable-autoscaling --enable-image-streaming \
  --num-nodes=0 --min-nodes=0 --max-nodes=3 \
  --node-locations $REGION-a,$REGION-b \
  --region $REGION # --spot
```

## Set Up Access to NVIDIA NIM
Access to NVIDIA NIM is available through the NVIDIA Early Access (EA) Program.  <INSERT Text From NVIDIA>

Get your NGC_API_KEY from NGC - TODO: Add detailed instructions and link to NVIDIA docs
```bash
export NGC_CLI_API_KEY="<YOUR_API_KEY>"
```

Ensure you have access to the repository by list the models
```bash
ngc registry model list "ohlfw0olaadg/ea-participants/*"
```

Add the NVIDIA NIM helm repo
```bash
helm repo add nemo-ms "https://helm.ngc.nvidia.com/ohlfw0olaadg/ea-participants" --username=\$oauthtoken --password=$NGC_CLI_API_KEY
```

## Convert the Llama 2 Chat Model to be compatible with L4 GPUs
https://developer.nvidia.com/docs/nemo-microservices/inference/model-repo-generator.html#llama-2-chat-models
<TODO: Add step by step instructions>

## Deploy the NIM with the generated engine using a Helm chart
<TODO: Add step by step instructions>

## Test the NIM
<TODO: Add step by step instructions>>

## Appendix

```
helm fetch https://helm.ngc.nvidia.com/ohlfw0olaadg/ea-participants/charts/nemollm-inference-0.1.3-rc6.tgz --username='$oauthtoken' --password=${NGC_API_KEY?}
tar -xvf nemollm-inference-0.1.3-rc6.tgz
```