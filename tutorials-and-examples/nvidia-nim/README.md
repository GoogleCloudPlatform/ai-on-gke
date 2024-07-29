# NVIDIA NIM on GKE

## Before you begin

1. Get access to NVIDIA NIMs
> [!IMPORTANT]
> Before you proceed further, ensure you have the NVIDIA AI Enterprise License (NVAIE) to access the NIMs.  To get started, go to [build.nvidia.com](https://build.nvidia.com/explore/discover?signin=true) and provide your company email address

2. In the [Google Cloud console](https://console.cloud.google.com), on the project selector page, select or create a new project with [billing enabled](https://cloud.google.com/billing/docs/how-to/verify-billing-enabled#console)

3. Ensure you have the following tools installed on your workstation
* [gcloud CLI](https://cloud.google.com/sdk/docs/install)
* [gcloud kubectl](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_kubectl)
* [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
* [jq](https://jqlang.github.io/jq/)
* [ngc](https://ngc.nvidia.com/setup)

4. Enable the required APIs
```bash
gcloud services enable \
  container.googleapis.com \
  file.googleapis.com
```

## Set up your GKE Cluster

1. Choose your region and set your project and machine variables:
```bash
export PROJECT_ID=$(gcloud config get project)
export REGION=us-central1
export ZONE=${REGION?}-b
export MACH=a2-highgpu-1g
export GPU_TYPE=nvidia-tesla-a100
export GPU_COUNT=1
```


2. Create a GKE cluster:
```bash
gcloud container clusters create nim-demo --location ${REGION?} \
  --workload-pool ${PROJECT_ID?}.svc.id.goog \
  --enable-image-streaming \
  --enable-ip-alias \
  --node-locations ${ZONE?} \
  --workload-pool=${PROJECT_ID?}.svc.id.goog \
  --addons=GcpFilestoreCsiDriver  \
  --machine-type n2d-standard-4 \
  --num-nodes 1 --min-nodes 1 --max-nodes 5 \
  --ephemeral-storage-local-ssd=count=2
```

3. Create a nodepool
```bash
gcloud container node-pools create ${MACH?}-node-pool --cluster nim-demo \
   --accelerator type=${GPU_TYPE?},count=${GPU_COUNT?},gpu-driver-version=latest \
  --machine-type ${MACH?} \
  --ephemeral-storage-local-ssd=count=${GPU_COUNT?} \
  --enable-autoscaling --enable-image-streaming \
  --num-nodes=1 --min-nodes=1 --max-nodes=3 \
  --node-locations ${ZONE?} \
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

4. Create a Kuberntes namespace
```bash
kubectl create namespace nim
```

## Deploy a PVC to persist the model
1. Create a PVC to persist the model weights - recommended for deployments with more than one (1) replica.  Save the following yaml as `pvc.yaml`.
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: model-store-pvc
  namespace: nim
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 30Gi
  storageClassName: standard-rwx
```

2. Apply PVC
```bash
kubectl apply -f pvc.yaml
```
> [!NOTE]
> This PVC will [dynamically provision a PV](https://cloud.google.com/kubernetes-engine/docs/concepts/persistent-volumes#dynamic_provisioning) with the necessary storage to persist model weights across replicas of your pods.

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
kubectl port-forward --namespace nim services/demo-nim-nim-llm 8000
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