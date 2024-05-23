# NVIDIA NIM on GKE with NVIDIA A100s

## Prerequisites
* docker
* golang
* yq

## Set up your GKE Cluster

Choose your region and set your project and machine variables:
```bash
export PROJECT_ID=$(gcloud config get project)
export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID?} --format="value(projectNumber)")
export REGION=us-central1
export ZONE=${REGION?}-b
export MACH=a2-highgpu-1g
export GPU_TYPE=nvidia-tesla-a100
export GPU_COUNT=1
```

Set model variables
```bash
export NGC_MODEL_NAME=llama-2-7b
export TRT_MODEL_NAME=trt_llm_0.0.1_trtllm
export TRITON_MODEL_NAME=trt_llm
export NGC_MODEL_VERSION=LLAMA-2-7B-4K-FP16
```


Create a GKE cluster:
```bash
gcloud container clusters create nim-demo --location ${REGION?} \
  --workload-pool ${PROJECT_ID?}.svc.id.goog \
  --enable-image-streaming \
  --enable-ip-alias \
  --node-locations=$REGION-a \
  --workload-pool=${PROJECT_ID?}.svc.id.goog \
  --addons=GcpFilestoreCsiDriver  \
  --machine-type n2d-standard-4 \
  --num-nodes 1 --min-nodes 1 --max-nodes 5 \
  --ephemeral-storage-local-ssd=count=2
```

Create a nodepool
```bash
gcloud container node-pools create ${MACH?}-node-pool --cluster nim-demo \
   --accelerator type=${GPU_TYPE?},count=${GPU_COUNT?},gpu-driver-version=latest \
  --machine-type ${MACH?} \
  --ephemeral-storage-local-ssd=count=${GPU_COUNT?} \
  --enable-autoscaling --enable-image-streaming \
  --num-nodes=1 --min-nodes=1 --max-nodes=3 \
  --node-locations ${REGION?}-b \
  --region ${REGION?}
  --spot
```

## Set Up Access to NVIDIA NIM
Access to NVIDIA NIM is available through the request form: https://www.nvidia.com/en-us/ai/nim-notifyme/ 

Get your NGC_API_KEY from NGC
```bash
export NGC_CLI_API_KEY="<YOUR_API_KEY>"
```

Ensure you have access to the repository by listing the models
```bash
ngc registry model list "ohlfw0olaadg/ea-participants/*"
```

Add the NVIDIA NIM helm repo
```bash
helm repo add nemo-ms "https://helm.ngc.nvidia.com/ohlfw0olaadg/ea-participants" --username=\$oauthtoken --password=$NGC_CLI_API_KEY
```

Create a Kuberntes namespace and switch context to that namespace
```bash
kubectl create namespace nim
kubectl config set-context --current --namespace nim

```
Create Kubernetes secrets to enable access to NGC resources from within your cluster
```bash
kubectl -n nim create secret docker-registry registry-secret --docker-server=nvcr.io --docker-username='$oauthtoken' --docker-password=$NGC_CLI_API_KEY
kubectl -n nim create secret generic ngc-api --from-literal=NGC_CLI_API_KEY=$NGC_CLI_API_KEY
```
## Deploy a PVC to persist the model

```bash
kubectl apply -f apply -f pvc.yaml
```

## Deploy the NIM with the generated engine using a Helm chart

```bash
# create a service account if it hasn't already been created
kubectl create serviceaccount nim-demo
```

Deploy the helm chart.  NOTE: We're making a small patch on the chart based [this known issue](#issue-chart-incompatible-version)
```bash
helm pull nemo-ms/nemollm-inference --version=0.1.2 --untar
yq -i '.kubeVersion = ">=v1.23.0-1"' ./nemollm-inference/Chart.yaml
```

```bash
envsubst < values.${GPU_TYPE?}.yaml | helm --namespace nim install inference-ms-${GPU_TYPE?} ./nemollm-inference --version=0.1.2 -f -
```

## Test the NIM
Expose the service
```bash
kubectl port-forward services/inference-ms-nemollm-inference 8005
```

Send a test prompt - A100
```bash
curl -X 'POST' \
  'http://localhost:8005/v1/chat/completions' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "messages": [
    {
      "content": "You are a polite and respectful chatbot helping people plan a vacation.",
      "role": "system"
    },
    {
      "content": "What should I do for a 4 day vacation in Spain?",
      "role": "user"
    }
  ],
  "model": "llama-2-7b-chat",
  "max_tokens": 160,
  "top_p": 1,
  "n": 1,
  "stream": false,
  "stop": "\n",
  "frequency_penalty": 0.0
}' | jq '.choices[0].message.content' -
```


## Appendix

### Known Issues

#### nemollm-inference helm chart incompatible version {#issue-chart-incompatible-version}
```bash
$ helm --namespace nim install my-inference-ms nemo-ms/nemollm-inference --version=0.1.2 -f values.yaml

Error: INSTALLATION FAILED: chart requires kubeVersion: >=v1.23.0 which is incompatible with Kubernetes v1.27.8-gke.1067004
```