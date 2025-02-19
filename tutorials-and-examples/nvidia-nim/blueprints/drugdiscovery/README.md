# Generative Virtual Screening for Drug Discovery on GKE

This guide outlines the steps to deploy NVIDIA's NIM blueprint for [Generative Virtual screening for Drug Discovery](https://build.nvidia.com/nvidia/generative-virtual-screening-for-drug-discovery) on a Google Kubernetes Engine (GKE) cluster. Three NIMs - AlphaFold2, MolMIM & DiffDock are used to demonstrate Protein folding, Molecular generation and Protein docking.

## Prerequisites

* **GCloud SDK:** Ensure you have the Google Cloud SDK installed and configured.
* **Project:**  A Google Cloud project with billing enabled.
* **NGC API Key:** An API key from NVIDIA NGC.
* **kubectl:**  kubectl command-line tool installed and configured.
* **NVIDIA GPUs:** One of the below GPUs should work
  * [NVIDIA L4 GPU (4)](https://cloud.google.com/compute/docs/gpus#l4-gpus)
  * [NVIDIA A100 80GB (1) GPU](https://cloud.google.com/compute/docs/gpus#a100-gpus)
  * [NVIDIA H100 80GB (1) GPU or higher](https://cloud.google.com/compute/docs/gpus#a3-series)

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
    export MACHINE_TYPE="<GCP machine type>" # e.g., g2-standard-48 (L4) or a2-ultragpu-1g (A100 80GB)
    export ACCELERATOR_TYPE="<GPU Type>" # e.g., nvidia-l4 (L4) or nvidia-a100-80gb (A100 80GB)
    export ACCELERATOR_COUNT="1" # e.g., 4 (L4) or 1 (A100 80GB)
    export NODE_POOL_NODES=3 # e.g., 1 (L4) or 3 (A100 80GB)
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

3. **Create GPU Node Pool:** This creates a node pool with GPU machines optimized for running the NIMs.

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
        --disk-size="200GB"
    
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

7. **Deploy Blueprint:** Deploy AlphaFold2, MolMIM, and DiffDock.

    ```bash

    k create -f nim-storage-filestore.yaml

    ```
  
    The creation and mounting of filestore might take few minutes.

     ```bash
    
    k create -f nim-bp-generative-virtual-screening.yaml

     ```

   > NOTE:
   > The AlphaFold2 NIM requires downloading supporting data from NGC. This process can take typically around 2-3 hours. Alternatively, you could copy the downloaded data into a persistent disk like NFS or Google Cloud storage bucket and use for future inference in few minutes. [Steps](#cache-alphafold2-data) outlined below.
  
   You can check the pods are in `Running` status: `k get pods` should list 3 pods: `alphafold2-`, `diffdock-` and `molmim-`.

   | NAME | READY | STATUS | RESTARTS |
   |---|---|---|---|
   |`alphafold2-aa-aa` | 1/1 | Running | 0 |
   |`diffdock-bb-bb` | 1/1 | Running | 0 |
   |`molmim-cc-cc` | 1/1 | Running | 0 |

8. **Port Forwarding (for local testing):**  The below commands forward the service ports to your local machine for testing. You will need a terminal to run these

   > NOTE:
   > It is assumed that the local ports 8010-8012 are available. If they are unavailable, do update them below and in the curl statements in following step.

    ```bash

    POD_NIM_ALPHAFOLD=$(k get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep '^alphafold2')
    k port-forward pod/$POD_NIM_ALPHAFOLD 8010:8000 &

    POD_NIM_MOLMIM=$(k get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep '^molmim')
    k port-forward pod/$POD_NIM_MOLMIM 8011:8000 &
    
    POD_NIM_DIFFDOCK=$(k get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep '^diffdock')
    k port-forward pod/$POD_NIM_DIFFDOCK 8012:8000 &
  
    ```

9. **Test Deployments:**  In a new terminal, Use `curl` or other tools to test the deployed services by sending requests to the forwarded ports. Examples are provided in the `dev.sh` file.

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

10. **Test end to end:** The test for protein folding, molecule generation and protein docking might take about 5-8 mins to run.

    > NOTE:
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
   k delete -f nim-bp-generative-virtual-screening.yaml
   k delete -f nim-storage-filestore.yaml
   gcloud container clusters delete "${CLUSTER_NAME}" --location="${ZONE}"

   ```

## Cache AlphaFold2 data

1. Create a GCS bucket `gs://nim-bp-alphafold2-cache-{project-number}`

2. Copy contents (`/data/ngc/hub/models--nim--deepmind--alphafold2-data`) to the bucket `gs://nim-bp-alphafold2-cache/ngc/hub/models--nim--deepmind--alphafold2-data/`

3. For future inference, copy the contents into the mounted NFS volume before deploying the blueprint (step 7). If the destination page is changed, you need to update the volume mount path (nim-bp-generative-virtual-screening.yaml) in `alphafold2` containers.

   ```bash

   gcloud storage cp -r gs://nim-bp-alphafold2-cache/ngc/hub/models--nim--deepmind--alphafold2-data/ /data/ngc/hub/

   ```
