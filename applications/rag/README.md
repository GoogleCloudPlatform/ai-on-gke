# RAG-on-GKE Application

**NOTE:** This solution is in beta. Please expect friction while using it.

This is a sample to deploy a RAG application on GKE. Retrieval Augmented Generation (RAG) is a popular approach for boosting the accuracy of LLM responses, particularly for domain specific or private data sets. The basic idea is to have a semantically searchable knowledge base (often using vector search), which is used to retrieve relevant snippets for a given prompt to provide additional context to the LLM. Augmenting the knowledge base with additional data is typically cheaper than fine tuning and is more scalable when incorporating current events and other rapidly changing data spaces.

Architecture:
1. A k8s service serving Hugging Face TGI inference using `mistral-7b`.
2. Cloud SQL `pgvector` instance with vector embeddings generated from the input dataset.
3. A k8s front end chat interface to interact with the inference server and the vector DB.
4. Ray cluster runs job to populate vector DB.
5. Jupyter notebook to read dataset and trigger ray job to populate the vector DB.

## Installation

Preinstall the following on your computer:
* Kubectl
* Terraform
* Helm
* Gcloud

**NOTE:** Terraform keeps state metadata in a local file called `terraform.tfstate`. Deleting the file may cause some resources to not be cleaned up correctly even if you delete the cluster. We suggest using `terraform destory` before reapplying/reinstalling.

### Infra Setup

#### GKE Cluster Setup

1. Set your cluster name and cloud region:
```
CLUSTER_NAME=rag-cluster
CLUSTER_REGION=us-central1
```
2. Use the following instructions to create a GKE cluster. We recommend using Autopilot for a simpler setup.

##### Autopilot (recommended)

RAG requires the latest Autopilot features, available on GKE cluster version `1.29.1-gke.1575000`+
```
CLUSTER_VERSION=1.29.1-gke.1589000
```

To create an Autopilot cluster, run:
```
gcloud container clusters create-auto ${CLUSTER_NAME:?} \
  --location ${CLUSTER_REGION:?} \
  --cluster-version ${CLUSTER_VERSION:?}
```

##### Standard

1. To create a GKE Standard cluster using Terraform, follow the [instructions here](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/infrastructure/README.md). Use the preconfigured node pools in `/infrastructure/platform.tfvars` as this solution requires T4s and L4s.

#### Setup Components

Next, set up the inference server, the `pgvector` instance, Jupyterhub, Kuberay and the frontend chat interface:

1. `cd ai-on-gke/applications/rag`

2. Edit `workloads.tfvars` with your project ID, cluster name, location and a GCS bucket name.
    * The GCS bucket name needs to be globally unique so add some random suffix to it (ensure `gcloud storage buckets describe gs://<bucketname>` returns a 404).
    * Optionally choose the k8s namespace & service account to be used by the application. If not selected, these resources will be created based on the default values set.

3. Run `terraform init`

4. Run `terraform apply --var-file workloads.tfvars`

5. Optionally, enable Cloud Data Loss Prevention (DLP)

We have two ways to enable the api:

    1. Go to https://console.developers.google.com/apis/api/dlp.googleapis.com/overview click enable api.
    2. Run command: `gcloud services enable dlp.googleapis.com`

This filter can auto fetch the templates in your project. Please refer to the following links to create templates:

    1. Inspect templates: https://cloud.google.com/dlp/docs/creating-templates-inspect
    2. De-identification templates: https://cloud.google.com/dlp/docs/creating-templates-deid

#### Verify Setup

Set your namespace from `workloads.tfvars`:
```
NAMESPACE=rag
```

Ensure your k8s client is using the correct cluster by running:
```
gcloud container clusters get-credentials ${CLUSTER_NAME:?} --location ${CLUSTER_REGION:?}
```

1. Verify Kuberay is setup: run `kubectl get pods -n ${NAMESPACE:?}`. There should be a Ray head (and Ray worker pod on GKE Standard only) in `Running` state (prefixed by `example-cluster-kuberay-head-` and `example-cluster-kuberay-worker-workergroup-`).

2. Verify Jupyterhub service is setup:
    * Fetch the service IP/Domain:
      * IAP disabled: `kubectl get services proxy-public -n $NAMESPACE --output jsonpath='{.status.loadBalancer.ingress[0].ip}'`
      * IAP enabled: Read terraform output `jupyter_uri` or use command: `kubectl get managedcertificates jupyter-managed-cert -n $NAMESPACE --output jsonpath='{.status.domainStatus[0].domain}'`
          * Remember login [Google Cloud Platform IAP](https://pantheon.corp.google.com/security/iap) to check if user has role `IAP-secured Web App User`
          * Wait for domain status to be `Active`
    * Go to the IP in a browser which should display the Jupyterlab login UI.

3. Verify the instance `pgvector-instance` exists: `gcloud sql instances list | grep pgvector`

4. Verify the inference server is setup:
    * Start port forwarding:
```
kubectl port-forward -n ${NAMESPACE:?} deployment/mistral-7b-instruct 8080:8080
```

    * In a new terminal, try a few prompts:
```
export USER_PROMPT="How to deploy a container on K8s?"
```
```
curl 127.0.0.1:8080/generate -X POST \
    -H 'Content-Type: application/json' \
    --data-binary @- <<EOF
{
    "inputs": "[INST] <<SYS>>\nYou are a helpful, respectful and honest assistant. Always answer as helpfully as possible, while being safe.  Your answers should not include any harmful, unethical, racist, sexist, toxic, dangerous, or illegal content. Please ensure that your responses are socially unbiased and positive in nature. If a question does not make any sense, or is not factually coherent, explain why instead of answering something not correct. If you don't know the answer to a question, please don't share false information.\n<</SYS>>\n${USER_PROMPT:?}[/INST]",
    "parameters": {"max_new_tokens": 400}
}
EOF
```

    * At the end of the smoke test with the TGI server, stop port forwarding by using Ctrl-C on the original terminal.

5. Verify the frontend chat interface is setup:
   * Verify the service exists: `kubectl get services rag-frontend -n ${NAMESPACE:?}`
   * Verify the deployment exists: `kubectl get deployments rag-frontend -n ${NAMESPACE:?}` and ensure the deployment is in `READY` state.
   * Verify the managed certificate is `Active`: 
      ```
     kubectl get managedcertificates frontend-managed-cert -n rag --output jsonpath='{.status.domainStatus[0].status}'
      ```
   * Verify IAP is enabled: 
      ```
      gcloud compute backend-services list --format="table(name, backends, iap.enabled)"
      ```

### Vector Embeddings for Dataset

Choose a password for your CloudSQL user:
```
SQL_PASSWORD=
```

This step generates the vector embeddings for your input dataset. Currently, the default dataset is [Google Maps Restaurant Reviews](https://www.kaggle.com/datasets/denizbilginn/google-maps-restaurant-reviews). We will use a Jupyter notebook to run a Ray job that generates the embeddings & populates them into the instance `pgvector-instance` created above.

1. Create a CloudSQL user to access the database: `gcloud sql users create rag-user-notebook --password=${SQL_PASSWORD:?} --instance=pgvector-instance --host=%`

2. Go to the Jupyterhub service endpoint in a browser:       
   * IAP disabled: `kubectl get services proxy-public -n $NAMESPACE --output jsonpath='{.status.loadBalancer.ingress[0].ip}'`
   * IAP enabled: Read terraform output `jupyter_uri` or use command: `kubectl get managedcertificates jupyter-managed-cert -n $NAMESPACE --output jsonpath='{.status.domainStatus[0].domain}'`
       * Open Google Cloud Console IAM to verify that the user has role `IAP-secured Web App User`
       * Wait for the domain status to be `Active`
3. Login with placeholder credentials [TBD: replace with instructions for IAP]:
    * username: user
    * password: use `terraform output jupyter_password` to fetch the password value

4. Once logged in, choose the `CPU` preset. Go to File -> Open From URL & upload the notebook `rag-kaggle-ray-sql.ipynb` from `https://raw.githubusercontent.com/GoogleCloudPlatform/ai-on-gke/main/applications/rag/example_notebooks/rag-kaggle-ray-sql-latest.ipynb`. This path can also be found by going to the [notebook location](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/applications/rag/example_notebooks/rag-kaggle-ray-sql-latest.ipynb) and selecting `Raw`.

5. Replace the variables in the 3rd cell with the following to access the database:
    * `INSTANCE_CONNECTION_NAME`: `<project_id>:<region>:pgvector-instance`
    * `DB_USER`: `rag-user-notebook`
    * `DB_PASS`: password from step 1

6. Create a Kaggle account and navigate to https://www.kaggle.com/settings/account and generate an API token. See https://www.kaggle.com/docs/api#authentication how to create one from https://kaggle.com/settings. This token is used in the notebook to access the [Google Maps Restaurant Reviews dataset](https://www.kaggle.com/datasets/denizbilginn/google-maps-restaurant-reviews)

8. Replace the kaggle username and api token in 2nd cell with your credentials (can be found in the `kaggle.json` file created by Step 6):
    * `os.environ['KAGGLE_USERNAME']`
    * `os.environ['KAGGLE_KEY']`

9. Run all the cells in the notebook. This will generate vector embeddings for the input dataset (`denizbilginn/google-maps-restaurant-reviews`) and store them in the `pgvector-instance` via a Ray job.
    * If the Ray job has FAILED, re-run the cell.
    * When the Ray job has SUCCEEDED, we are ready to launch the frontend chat interface.

### Access the Frontend Chat Interface

#### With IAP Disabled
1. Setup port forwarding for the frontend: `kubectl port-forward service/rag-frontend -n $NAMESPACE 8080:8080 &`

2. Go to `localhost:8080` in a browser & start chatting! This will fetch context related to your prompt from the vector embeddings in the `pgvector-instance`, augment the original prompt with the context & query the inference model (`mistral-7b`) with the augmented prompt.

#### With IAP Enabled
1. Verify that IAP is enabled on Google Cloud Platform (GCP) for your application. If you encounter any errors, try re-enabling IAP.
2. Verify that you have the role `IAP-secured Web App User` assigned to your user account. This role is necessary to access the application through IAP.
3. Verify the domain is active using command:
    `kubectl get managedcertificates frontend-managed-cert -n rag --output jsonpath='{.status.domainStatus[0].status}'`
3. Read terraform output `frontend_uri` or use the following command to find the domain created by IAP for accessing your service:
    `kubectl get managedcertificates frontend-managed-cert -n $NAMESPACE --output jsonpath='{.status.domainStatus[0].domain}'`
4.  Open your browser and navigate to the domain you retrieved in the previous step to start chatting!

#### Prompt Examples

*TODO:* Add some example prompts for the dataset.

### Cleanup

1. Run `terraform destroy --var-file="workloads.tfvars"`
