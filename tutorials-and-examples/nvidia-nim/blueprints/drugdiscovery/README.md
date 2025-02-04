# Generative Virtual Screening for Drug Discovery on GKE

This guide outlines the steps to deploy NVIDIA's NIM blueprint for [Generative Virtual screening for Drug Discovery](https://build.nvidia.com/nvidia/generative-virtual-screening-for-drug-discovery) on a Google Kubernetes Engine (GKE) cluster. Three NIMs - AlphaFold2, MolMIM & DiffDock are used to demonstrate Protein folding, molecular generation and protein docking.

## Prerequisites

* **GCloud SDK:** Ensure you have the Google Cloud SDK installed and configured.
* **Project:**  A Google Cloud project with billing enabled.
* **NGC API Key:** An API key from NVIDIA NGC.
* **kubectl:**  kubectl command-line tool installed and configured.
* **NVIDIA GPUs:**  NVIDIA A100 80GB(3) GPU preferred in the same region / zone.

Clone the repo before proceeding further:

```bash

git clone https://github.com/GoogleCloudPlatform/ai-on-gke
cd ai-on-gke/tutorials-and-examples/nvidia-nim/blueprints/drugdiscovery

```

## Deployment Steps

1. **Set Project and Variables:**

    ```bash

    gcloud config set project "<GCP Project ID>"
    export PROJECT_ID=$(gcloud config get project)
    export CLUSTER_NAME="gke-nimbp-genscr"
    export NODE_POOL_NAME="gke-nimbp-genscr-np"
    export ZONE="<GCP zone>" #us-east5-b
    export MACHINE_TYPE= "<GCP machine type>" #"a2-ultragpu-1g"
    export ACCELERATOR_TYPE="<GPU Type>" #"nvidia-a100-80gb"
    export ACCELERATOR_COUNT="1"
    export NODE_POOL_NODES=3
    export NGC_API_KEY="<NGC API Key>"

    ```

2. **Create GKE Cluster:** This creates the initial cluster with a default node pool for management tasks. GPU nodes will be added in the next step.

    ```bash

    gcloud container clusters create "${CLUSTER_NAME}" \
      --project="${PROJECT_ID}" \
      --num-nodes=1 --location="${ZONE}" \
      --machine-type="e2-standard-2" \
      --addons=GcpFilestoreCsiDriver
  
    ```

3. **Create GPU Node Pool:** This creates a node pool with GPU machines optimized for BioNeMo workloads.

    ```bash

    gcloud container node-pools create "${NODE_POOL_NAME}" \
        --cluster="${CLUSTER_NAME}" \
        --location="${ZONE}" \
        --node-locations="${ZONE}" \
        --num-nodes="${NODE_POOL_NODES}" \
        --machine-type="${MACHINE_TYPE}" \
        --accelerator="type=${ACCELERATOR_TYPE},count=${ACCELERATOR_COUNT},gpu-driver-version=LATEST" \
        --placement-type="COMPACT" \
        --disk-type="pd-ssd" \
        --disk-size="500GB"
    
    ```

4. **Get Cluster Credentials:**

    ```bash

    gcloud container clusters get-credentials "${CLUSTER_NAME}" --location="${ZONE}"

    ```

5. **Set kubectl Alias (Optional):**

    ```bash
    
    alias k=kubectl

    ```

6. **Create NGC API Key Secret:** Creates secrets for pulling images from NVIDIA NGC and pods that need the API key at startup.

    ```bash

    k create secret docker-registry secret-nvcr \
      --docker-username=\$oauthtoken \
      --docker-password="${NGC_API_KEY}" \
      --docker-server="nvcr.io"
    
    k create secret generic ngc-api-key \
      --from-literal=NGC_API_KEY="${NGC_API_KEY}"

    ```

7. **Deploy BioNeMo Services:** Deploy AlphaFold2, MolMIM, and DiffDock.

    ```bash

    k create -f nim-storage-filestore.yaml
    k create -f nim-bionemo-generative-virtual-screening.yaml 

    ```

8. **Port Forwarding (for local testing):**  These commands forward the service ports to your local machine for testing.

> [!NOTE]
> It is assumed that the local ports 8010-8012 are available. If they are unavailable, do update them below and in the curl statements in following step.

    ```bash

    POD_BIONEMO_ALPHAFOLD=$(k get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep '^alphafold2')
    k port-forward pod/$POD_BIONEMO_ALPHAFOLD 8010:8000

    POD_BIONEMO_MOLMIM=$(k get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep '^molmim')
    k port-forward pod/$POD_BIONEMO_MOLMIM 8011:8000
    
    POD_BIONEMO_DIFFDOCK=$(k get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep '^diffdock')
    k port-forward pod/$POD_BIONEMO_DIFFDOCK 8012:8000
  
    ```

9. **Test Deployments:**  Use `curl` or other tools to test the deployed services by sending requests to the forwarded ports. Examples are provided in the `dev.sh` file.

    ```bash
  
    # AlphaFold2
    curl \
    --max-time 900 \
    -X POST \
    -i \
    "http://localhost:8010/protein-structure/alphafold2/predict-structure-from-sequence" \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{
      "sequence": "MVPSAGQLALFALGIVLAACQALENSTSPLSADPPVAAAVVSHFNDCPDSHTQFCFHGTCRFLVQEDKPACVCHSGYVGARCEHADLLAVVAASQKKQAITALVVVSIVALAVLIITCVLIHCCQVRKHCEWCRALICRHEKPSALLKGRTACCHSETVV",
      "databases": [
        "small_bfd"
      ]
    }'
  
    ```
  
    ```bash
  
    # MolMIM
    curl -X POST \
    -H 'Content-Type: application/json' \
    -d '{
      "smi": "CC1(C2C1C(N(C2)C(=O)C(C(C)(C)C)NC(=O)C(F)(F)F)C(=O)NC(CC3CCNC3=O)C#N)C",
      "num_molecules": 5,
      "algorithm": "CMA-ES",
      "property_name": "QED",
      "min_similarity": 0.7,
      "iterations": 10
    }' \
    "http://localhost:8011/generate"
  
    ```

10. **Test end to end:**

> [!NOTE]
> If the port numbers were changed earlier, then update the `AF2_HOST`, `MOLMIM_HOST`, `DIFFDOCK_HOST` variables with port numbers in `test-generative-virtual-screening.py` file.

    ```bash

    python3 -m venv venv
    source venv/bin/activate
    pip3 install requests
    python3 test-generative-virtual-screening.py
    deactivate

    ```

## Cleanup

   To delete the cluster and all associated resources:

   ```bash

   k delete secret secret-nvcr
   k delete secret ngc-api-key
   k delete -f nim-bionemo-generative-virtual-screening.yaml
   k delete -f nim-storage-filestore.yaml
   gcloud container clusters delete "${CLUSTER_NAME}" --location="${ZONE}"

   ```
