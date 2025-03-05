# Digital Human for Customer Service on GKE

Deploying the digital human blueprint based on few NIMs on GKE.

## Table of Contents

- [Digital Human for Customer Service on GKE](#digital-human-for-customer-service-on-gke)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Setup](#setup)
  - [Tear down](#tear-down)

## Prerequisites

- **GCloud SDK:** Ensure you have the Google Cloud SDK installed and configured.
- **Project:**  A Google Cloud project with billing enabled.
- **NGC API Key:** An API key from NVIDIA NGC. Please read the prerequisites to access this key [here](https://github.com/NVIDIA-AI-Blueprints/digital-human/blob/main/README.md#prerequisites)
- **kubectl:**  kubectl command-line tool installed and configured.
- **NVIDIA GPUs:** One of the below GPUs should work
  - [NVIDIA L4 GPU (8)](https://cloud.google.com/compute/docs/gpus#l4-gpus)
  - [NVIDIA A100 80GB (1) GPU](https://cloud.google.com/compute/docs/gpus#a100-gpus)
  - [NVIDIA H100 80GB (1) GPU or higher](https://cloud.google.com/compute/docs/gpus#a3-series)

## Setup

1. **Environment setup**: You'll set up several environment variables to make the following steps easier and more flexible. These variables store important information like cluster names, machine types, and API keys. You need to update the variable values to match your needs and context.

    ```bash
    gcloud config set project "<GCP Project ID>"

    export CLUSTER_NAME="gke-nimbp-dighuman"
    export NP_NAME="gke-nimbp-dighuman-gpunp"

    export ZONE="us-west4-a"            # e.g., us-west4-a
    export NP_CPU_MACHTYPE="e2-standard-2" # e.g., e2-standard-2
    export NP_GPU_MACHTYPE="g2-standard-96" # e.g., a2-ultragpu-1g

    export ACCELERATOR_TYPE="nvidia-l4"     # e.g., nvidia-a100-80gb
    export ACCELERATOR_COUNT="8"            # Or higher, as needed
    export NODE_POOL_NODES=1                # Or higher, as needed

    export NGC_API_KEY="<NGC API Key>"

    ```

2. **GKE Cluster creation**:

    ```bash

    gcloud container clusters create "${CLUSTER_NAME}" \
      --num-nodes="1" \
      --location="${ZONE}" \
      --machine-type="${NP_CPU_MACHTYPE}" \
      --gateway-api=standard \
      --addons=GcpFilestoreCsiDriver,HttpLoadBalancing

    gcloud container node-pools create "${NP_NAME}" \
      --cluster="${CLUSTER_NAME}" \
      --location="${ZONE}" \
      --node-locations="${ZONE}" \
      --num-nodes="${NODE_POOL_NODES}" \
      --machine-type="${NP_GPU_MACHTYPE}" \
      --accelerator="type=${ACCELERATOR_TYPE},count=${ACCELERATOR_COUNT},gpu-driver-version=LATEST" \
      --placement-type="COMPACT" \
      --disk-type="pd-ssd" \
      --disk-size="300GB"

    ```

3. **Deploy NIMs:**

    ```bash

    gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --location="${ZONE}"

    alias k=kubectl

    k create secret docker-registry secret-nvcr \
      --docker-username=\$oauthtoken \
      --docker-password="${NGC_API_KEY}" \
      --docker-server="nvcr.io"

    k create secret generic ngc-api-key \
      --from-literal=NGC_API_KEY="${NGC_API_KEY}"

    k apply -f digital-human-nimbp.yaml

    ```

    The NIM deployment takes upto 15mins for it to be complete. You can check the pods are in `Running` status: `k get pods` should list below pods.

    | NAME | READY | STATUS | RESTARTS |
    |---|---|---|---|
    |`dighum-embedqa-e5v5-aa-aa` | 1/1 | Running | 0 |
    |`dighum-rerankqa-mistral4bv3-bb-bb` | 1/1 | Running | 0 |
    |`dighum-llama3-8b-cc-cc` | 1/1 | Running | 0 |
    |`dighum-audio2face-3d-dd-dd` | 1/1 | Running | 0 |
    |`dighum-fastpitch-tts-ee-ee` | 1/1 | Running | 0 |
    |`dighum-maxine-audio2face-2d-ff-ff` | 1/1 | Running | 0 |
    |`dighum-parakeet-asr-1-1b-gg-gg` | 1/1 | Running | 0 |

4. **Access NIM endpoints**

    ```bash

    SERVICES=$(k get svc | awk '{print $1}' | grep -v NAME | grep '^dighum')

    for service in $SERVICES; do
      # Get the pod name.
      POD=$(k get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep $(echo $service | sed 's/-lb//'))

      # Get external IP.
      EXTERNAL_IP=$(k get svc $service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

      echo "----------------------------------"
      echo "Testing service: $service"
      curl http://${EXTERNAL_IP}/v1/health/ready
      echo " "
      echo "----------------------------------"
    done

    ```

    [Click here if you need HTTPS endpoints](https.md)

## Tear down

5. **Tear down the environment**
    **NOTE:** Please note all the NIMs deployed and cluster will be deleted.

    ```bash

    k delete -f digital-human-nimbp.yaml
    k delete secret secret-nvcr
    k delete secret ngc-api-key
    gcloud container clusters delete "${CLUSTER_NAME}" \
    --location="${ZONE}" --quiet

    ```
