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

### (Optional) Use an existing cluster

By default, Terraform creates an Autopilot cluster on your behalf. If you prefer to manage your own cluster, you will need to set `create_cluster = false` in the following section. Creating a long-running cluster is also better for development, allowing you to iterate on Terraform components without recreating the cluster every time.

You can use gcloud to create a GKE Autopilot cluster. Note that RAG requires the latest Autopilot features, available on the `RAPID` release channel.

```
CLUSTER_NAME=rag-cluster
CLUSTER_REGION=us-central1

gcloud container clusters create-auto ${CLUSTER_NAME:?} \
  --location ${CLUSTER_REGION:?} \
  --release-channel rapid
```

#### Deploy terraform components

The following steps set up the cluster, inference server, pgvector CloudSQL instance, JupyterHub, KubeRay, and frontend chat interface.

1. `cd ai-on-gke/applications/rag`

2. Edit `workloads.tfvars` to set your project ID, location, cluster name, and GCS bucket name. Optionally, make the following changes:
    * Set `create_cluster = false` if you are using an existing cluster.
    * (Recommended) Set `jupyter_add_auth = true` and `frontend_add_auth = true` to create load balancers with IAP for your Jupyter notebook and TGI frontend.
    * Choose a custom k8s namespace and service account to be used by the application.

3. Run `terraform init`

4. Run `terraform apply --var-file workloads.tfvars`

5. Optionally, enable Cloud Data Loss Prevention (DLP)

    We have two ways to enable the api:

    1. Go to https://console.developers.google.com/apis/api/dlp.googleapis.com/overview click enable api.
    2. Run command: `gcloud services enable dlp.googleapis.com`

    This filter can auto fetch the templates in your project. Please refer to the following links to create templates:

    1. Inspect templates: https://cloud.google.com/dlp/docs/creating-templates-inspect
    2. De-identification templates: https://cloud.google.com/dlp/docs/creating-templates-deid

#### Verify setup

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
      * IAP disabled: `kubectl get services proxy-public -n $NAMESPACE --output jsonpath='{.spec.clusterIP}'` is not empty.
      * IAP enabled: Read terraform output: `terraform output jupyterhub_uri`:
          * From [Google Cloud Platform IAP](https://console.cloud.google.com/security/iap), check if the target user has role `IAP-secured Web App User`
          * Wait for domain status to be `Active` by using `kubectl get managedcertificates jupyter-managed-cert -n $NAMESPACE --output jsonpath='{.status.domainStatus[0].status}'`
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

### Vector embeddings for dataset

This step generates the vector embeddings for your input dataset. Currently, the default dataset is [Google Maps Restaurant Reviews](https://www.kaggle.com/datasets/denizbilginn/google-maps-restaurant-reviews). We will use a Jupyter notebook to run a Ray job that generates the embeddings & populates them into the instance `pgvector-instance` created above.

1. Fetch the Jupyterhub service endpoint & navigate to it in a browser. This should display the JupyterLab login UI:
   * IAP disabled: setup port forwarding for the frontend: `kubectl port-forward service/proxy-public -n $NAMESPACE 8081:80 &`, and go to `localhost:8081` in a browser
   * IAP enabled: Read terraform output: `terraform output jupyterhub_uri`.
       * From [Google Cloud Platform IAP](https://console.cloud.google.com/security/iap), check if the target user has role `IAP-secured Web App User`.
       * Wait for the domain status to be `Active` by using `kubectl get managedcertificates jupyter-managed-cert -n $NAMESPACE --output jsonpath='{.status.domainStatus[0].status}'`

2. Login to Jupyterhub:
   * IAP disabled: Use placeholder credentials:
        * username: admin
        * password: use `terraform output jupyterhub_password` to fetch the password value
   * IAP enabled: Login with your Google credentials.

3. Once logged in, choose the `CPU` preset. Go to File -> Open From URL & upload the notebook `rag-kaggle-ray-sql.ipynb` from `https://raw.githubusercontent.com/GoogleCloudPlatform/ai-on-gke/main/applications/rag/example_notebooks/rag-kaggle-ray-sql-latest.ipynb`. This path can also be found by going to the [notebook location](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/main/applications/rag/example_notebooks/rag-kaggle-ray-sql-latest.ipynb) and selecting `Raw`.

4. Create a Kaggle account and navigate to https://www.kaggle.com/settings/account and generate an API token. See https://www.kaggle.com/docs/api#authentication how to create one from https://kaggle.com/settings. This token is used in the notebook to access the [Google Maps Restaurant Reviews dataset](https://www.kaggle.com/datasets/denizbilginn/google-maps-restaurant-reviews)

5. Replace the variables in the 1st cell with your Kaggle credentials (can be found in the `kaggle.json` file created by Step 4):
    * `KAGGLE_USERNAME`
    * `KAGGLE_KEY`

6. Run all the cells in the notebook. This generates vector embeddings for the input dataset (`denizbilginn/google-maps-restaurant-reviews`) and stores them in the `pgvector-instance` via a Ray job.
    * When the last cell says the job has succeeded (eg: `Job 'raysubmit_APungAw6TyB55qxk' succeeded`), the vector embeddings have been generated and we can launch the frontend chat interface.
    * Ray may take several minutes to create the runtime environment. During this time, the job will appear to be missing (e.g. `Status message: Job has not started yet`).

### Launch the frontend chat interface

#### With IAP disabled
1. Setup port forwarding for the frontend: `kubectl port-forward service/rag-frontend -n $NAMESPACE 8080:8080 &`

2. Go to `localhost:8080` in a browser & start chatting! This will fetch context related to your prompt from the vector embeddings in the `pgvector-instance`, augment the original prompt with the context & query the inference model (`mistral-7b`) with the augmented prompt.

#### With IAP enabled
1. Verify that IAP is enabled on [Google Cloud Platform (GCP) IAP](https://console.cloud.google.com/security/iap)(make sure you are logged in) for your application. If you encounter any errors, try re-enabling IAP.
2. From *Google Cloud Platform IAP*, check if the target user has role `IAP-secured Web App User`. This role is necessary to access the application through IAP.
3. Verify the domain is active using command:
    `kubectl get managedcertificates frontend-managed-cert -n rag --output jsonpath='{.status.domainStatus[0].status}'`
4. Read terraform output: `terraform output frontend_uri` to find the domain created by IAP for accessing your service.
5. Open your browser and navigate to the domain you retrieved in the previous step to start chatting!

#### Prompt examples

*TODO:* Add some example prompts for the dataset.

### Cleanup

1. Run `terraform destroy --var-file="workloads.tfvars"`
