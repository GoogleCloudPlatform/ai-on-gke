# NVIDIA NIM on GKE with NVIDIA A100s

## Prerequisites
### Prerequisites

> [!IMPORTANT]
> Before you proceed further, ensure you have the NVIDIA AI Enterprise License (NVAIE) to access the NIMs.  To get started, go to [build.nvidia.com](https://build.nvidia.com/explore/discover?signin=true) and provide your company email address

* [Google Cloud Project](https://console.cloud.google.com) with billing enabled
* [gcloud CLI](https://cloud.google.com/sdk/docs/install)
* [gcloud kubectl](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_kubectl)
* [Terraform](https://developer.hashicorp.com/terraform/tutorials/gcp-get-started/install-cli)
* [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
*  [yq](https://pypi.org/project/yq/)

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
  --region ${REGION?} \
  --spot
```


## Set Up Access to NVIDIA NIMs and prepare environment

1. Get your NGC_API_KEY from NGC
```bash
export NGC_CLI_API_KEY="<YOUR_API_KEY>"
```
> [!NOTE]
> If you have not set up NGC, see [NGC Setup](https://ngc.nvidia.com/setup) to get your access key and begin using NGC.

2. As a part of the NGC setup, set your configs
```bash
ngc config set
```

3. Ensure you have access to the repository by listing the models
```bash
ngc registry model list
```

4. Create a Kuberntes namespace and switch context to that namespace
```bash
kubectl create namespace nim
kubectl config set-context --current --namespace nim
```

5. Create Kubernetes secrets to enable access to NGC resources from within your cluster
```bash
kubectl -n nim create secret docker-registry registry-secret --docker-server=nvcr.io --docker-username='$oauthtoken' --docker-password=$NGC_CLI_API_KEY
kubectl -n nim create secret generic ngc-api --from-literal=NGC_CLI_API_KEY=$NGC_CLI_API_KEY
```

## Deploy a PVC to persist the model
1. Clone this repository

2. Create a PVC to persist the model weights - recommended for deployments with more than one (1) replica.  Save the following yaml as `pvc.yaml` or use existing file in this repository
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: model-store-pvc
  namespace: nim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 30Gi
  storageClassName: standard-rwx
```

3. Apply PVC
```bash
kubectl apply -f pvc.yaml
```

## Deploy the NIM with the generated engine using a Helm chart

1. Clone the nim-deploy repository
```bash
git clone https://github.com/NVIDIA/nim-deploy.git
cd nim-deploy/helm
```

2. Deploy chart with minimal configurations
```bash
helm --namespace nim install demo-nim nim-llm/ --set model.ngcAPIKey=$NGC_CLI_API_KEY --set persistence.enabled=true --set persistence.existingClaim=model-store-pvc
```

## Test the NIM
1. Expose the service
```bash
kubectl port-forward services/demo-nim-nim-llm 8000
```

2. Send a test prompt - A100
```bash
curl -X 'POST' \
  'http://localhost:8000/v1/chat/completions' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "messages": [
    {
      "content": "You are a polite and respectful poet.",
      "role": "system"
    },
    {
      "content": "Write a limerick about the wonders of GPUs and Kubernetes?",
      "role": "user"
    }
  ],
  "model": "meta/llama3-8b-instruct",
  "max_tokens": 256,
  "top_p": 1,
  "n": 1,
  "stream": false,
  "frequency_penalty": 0.0
}' | jq '.choices[0].message.content' -
```

3. Browse the API by navigating to http://localhost:8000/docs