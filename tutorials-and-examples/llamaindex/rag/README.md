# Llamaindex in GKE cluster

[LlamaIndex](https://docs.llamaindex.ai/en/stable/) bridges the gap between LLMs and domain-specific datasets, enabling efficient indexing and querying of unstructured data for intelligent, data-driven responses. When deployed on a [GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/kubernetes-engine-overview) cluster, it ensures scalability and security by leveraging containerized workloads, GPU-based nodes, and seamless cloud-native integrations, making it ideal for ML-powered applications like RAG systems.

# Overview

This tutorial will guide you through creating a robust Retrieval-Augmented Generation (RAG) system using LlamaIndex and deploying it on Google Kubernetes Engine (GKE). 

## What will you learn

1. **Data Preparation and Ingestion:** Use LlamaIndex to structure and index your data for efficient querying.   
2. **Model Integration:** Connect LlamaIndex with an LLM to build a RAG pipeline that can generate precise responses based on your indexed data.   
3. **Containerization:** Package the application as a container for deployment.  
4. **GKE Deployment:** Set up a GKE cluster using [Terraform](https://developer.hashicorp.com/terraform?product_intent=terraform) and deploy your RAG system, leveraging Kubernetes features.

## Filesystem structure

* `app` \- folder with demo Python application that uses llamaindex to ingest data to RAG and infer it through web API.  
* `templates` \- folder with Kubernetes manifests that require additional processing to specify additional values that are not known from the start.  
* `terraform` \- folder with terraform config that executes automated provisioning of required infrastructure resources.

## Demo application

The demo application consist of following components:

### Data ingestion

The data ingestion is a process of adding data to be used by a RAG.  
It is defined in the `app/cmd/ingest_data.py`.


File: `app/cmd/ingest_data.py`
<details><summary>Expand to see key parts</summary>

 
```
pipeline = IngestionPipeline(
    transformations=[
        SentenceSplitter(),
        embed_model,
    ],
    docstore=RedisDocumentStore.from_host_and_port(
        REDIS_HOST, REDIS_PORT, namespace="document_store"
    ),
    vector_store=vector_store,
    cache=cache,
    docstore_strategy=DocstoreStrategy.UPSERTS,
)

```

   
The pipeline variable defined IngestionPipeline, that has the following arguments:

* `transformations`: defines a list of data transformation steps applied during the ingestion pipeline. In our case:  
  * `SentenceSplitter`: tries to keep sentences and paragraphs together. Therefore, compared to the original TokenTextSplitter, there are less likely to be hanging sentences or parts of sentences at the end of the node chunk.  
  * `embed_model`: an embedding model that generates vector representations for the processed text.  
* `docstore`: defines where the processed documents are stored for later retrieval.  
* `vector_store`: a place where the resulting nodes are placed.  
* `cache`: a place where to store a cache for a faster document search.  
* `docstore_strategy`: defines how the document store handles incoming data. In our case, it updates existing documents or inserts new ones if they don’t already exist.
</details>

File `app/rag_demo/__init__.py`:  

<details><summary>Expand to see key parts</summary>


In this demo we use [Redis-stack](https://redis.io/about/about-stack/) as our vector storage and we also have to define a data schema for it.

```
custom_schema = IndexSchema.from_dict(
    {
        "index": {"name": "bucket", "prefix": "doc"},
        # customize fields that are indexed
        "fields": [
            # required fields for llamaindex
            {"type": "tag", "name": "id"},
            {"type": "tag", "name": "doc_id"},
            {"type": "text", "name": "text"},
            # custom vector field for bge-small-en-v1.5 embeddings
            {
                "type": "vector",
                "name": "vector",
                "attrs": {
                    "dims": 384,
                    "algorithm": "hnsw",
                    "distance_metric": "cosine",
                },
            },
        ],
    }
)
```
</details>

### RAG server

Simple web application that invokes llamaindex RAG system and returns response. The web application will be a simple FastAPI app, so we can invoke the RAG system via HTTP request. It is defined in the `app/rag_demo/main.py` file as a FastAPI application and a single `/invoke` API and connection to the Redis Vector Store.

<details><summary>Expand to see key parts</summary>

```
embed_model = HuggingFaceEmbedding(model_name=EMBEDDING_MODEL_NAME)

# Connect to vector store with already ingested data
vector_store = RedisVectorStore(
    schema=custom_schema,
    redis_url=f"redis://{REDIS_HOST}:{REDIS_PORT}",
)

# Create index from a vector store
index = VectorStoreIndex.from_vector_store(
    vector_store, embed_model=embed_model
)

# Connect to LLM using Ollama
llm = Ollama(
    model=MODEL_NAME,
    base_url=OLLAMA_SERVER_URL,
)

# Create query engine that is ready to query our RAG
query_engine = index.as_query_engine(llm=llm)
```

</details>

### 

# Before you begin

Ensure you have a GCP project with a billing account.

Ensure you have the following tools installed on your workstation:

* [gcloud CLI](https://cloud.google.com/sdk/docs/install)  
* [gcloud kubectl](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_kubectl)  
* [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)  (for an automated deployment)

If you previously installed the gcloud CLI, get the latest version by running:

```
gcloud components update
```

 Ensure that you are signed in using the gcloud CLI tool. Run the following commands:

```
gcloud auth application-default login
```

# Infrastructure Setup

In this section we will use `Terraform` to automate the creation of infrastructure resources. For more details how it is done please refer to the terraform config in the `terraform` folder.   
By default it creates an Autopilot GKE cluster but it can be changed to standard by setting `autopilot_cluster=false`

It creates:

* IAM service accounts:  
	* for a cluster  
 	* for Kubernetes permissions for app deployments (using [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation))  
      	* GCS bucket to store data to be ingested to the RAG.  
	* [Artifact registry](https://cloud.google.com/artifact-registry/docs/overview) as a storage for an app-demo  image   
    



1. Go the the terraform directory:

```
cd terraform
```

2. Specify the following values inside the `default_env.tfvars` file (or make a separate copy):  
	- `<PROJECT_ID>` – replace with your project id (you can find it in the project settings).


Other values can be changed, if needed, but can be left with default values.

3. Optional. You can use a GCS bucket as a storage for a Terraform state.  [Create a bucket](https://cloud.google.com/storage/docs/creating-buckets#command-line) manually and then uncomment the content of the file `terraform/backend.tf` and specify your bucket:

```
terraform {
   backend "gcs" {
     bucket = "<BUCKET_NAME>"
     prefix = "terraform/state/llamaindex"
   }
 }
```

4. Init terraform modules:

```
terraform init
```

 

5. Optionally run the `plan` command to view an execution plan: 

```
terraform plan -var-file=default_env.tfvars
```

6. Execute the plan:

```
terraform apply -var-file=default_env.tfvars
```

And you should see your resources created:

```
Apply complete! Resources: 16 added, 0 changed, 0 destroyed.

Outputs:

bucket_name = "llamaindex-rag-demo-tf"
demo_app_image_repo_name = "llamaindex-rag-demo-tf"
gke_cluster_location = "us-central1"
gke_cluster_name = "llamaindex-rag-demo-tf"
project_id = "akvelon-gke-aieco"

```

7. Connect the cluster:

```
gcloud container clusters get-credentials $(terraform output -raw gke_cluster_name) --region $(terraform output -raw gke_cluster_location) --project $(terraform output -raw project_id)
```

# Deploy the application to the cluster

## 1. Deploy Redis-stack. 

   For this guide it was decided to use [redis-stack](https://hub.docker.com/r/redis/redis-stack) as a vector store, but there are many other [options](https://docs.llamaindex.ai/en/stable/module_guides/storing/vector_stores/).  
      
   IMPORTANT: For the simplicity of this guide, Redis  is deployed without persistent volumes, so the database is not persistent as well. Please consider proper persistence configuration for production. 

   1. Apply Redis-stack manifest:

```
kubectl apply -f ../redis-stack.yaml
```

   2. Wait for Redis-stack is successfully deployed

```
kubectl rollout status deployment/redis-stack
```

## 2.  Deploy Ollama server

   [Ollama](https://ollama.com/) is a tool that will run LLMs. It interacts with Llama-index through its [ollama integration](https://docs.llamaindex.ai/en/stable/api_reference/llms/ollama/) and will serve the desired model, the `gemma2-9b` in our case.

   1. Deploy resulting Ollama manifest:

```
kubectl apply -f ../gen/ollama-deployment.yaml
```
<details>
<summary>Key notes on the Ollama deployment 'ollama-deployment.yaml' file: </summary>

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
spec:
  ...
  template:
    metadata:
      ...
      annotations:
        gke-gcsfuse/volumes: 'true' # <- use FUSE to mount our bucket 
    spec:
      serviceAccount: ... # <- our service account 
      nodeSelector:
        cloud.google.com/gke-accelerator: nvidia-l4 # <- specify GPU type for LLM
      containers:
         ...
          volumeMounts: # <- mount bucket volume to be used by Ollama
            - name: ollama-data
              mountPath: /root/.ollama/ # <- Ollama's path where it stores models
          resources:
            limits:
              nvidia.com/gpu: 1 # <- Enable GPU
      volumes:
        - name: ollama-data # <- Volume with a bucket mounted with FUSE
          csi:
```
</details>

2. Wait for Ollama is successfully deployed:

```
kubectl rollout status deployment/ollama
```

   3. Pull the  `gemma2:9b` model within Ollama server pod:

```
kubectl exec $(kubectl get pod -l app=ollama -o name) -c ollama -- ollama pull gemma2:9b
```

## 3. Build the demo app image

   

   1. Build the  `llamaindex-rag-demo` container image using [Cloud Build](https://cloud.google.com/build/docs/overview) and push it to the repository that is created by terraform. It uses `cloudbuild.yaml` file which uses the `app/Dockerfile` for a build. That may take some time:

```
gcloud builds submit ../app \
--substitutions _IMAGE_REPO_NAME="$(terraform output -raw demo_app_image_repo_name)" \
--config ../cloudbuild.yaml
```

   More information about the container image and demo application can be found in the `app` folder.

## 4. Ingest data to the vector database by running a Kubernetes job.

   

   1. Upload sample data into our bucket, which is created by the Terraform. This data then will  be ingested to our RAG’s vector store.

```
curl -s https://raw.githubusercontent.com/run-llama/llama_index/main/docs/docs/examples/data/paul_graham/paul_graham_essay.txt | \
gcloud storage cp - gs://$(terraform output -raw bucket_name)/datalake/paul_graham_essay.txt
```

   2. Create ingestion job:

      

   The manifests are generated from templates in the `templates` directory and put in the `gen` directory.

      

```
kubectl apply -f ../gen/ingest-data-job.yaml
```

<details>
<summary>Key notes on the 'ingest-data-job.yaml' file: </summary>

```
apiVersion: batch/v1
kind: Job
spec:
  template:
    metadata:
      ...
      annotations:
        gke-gcsfuse/volumes: 'true'  # <- use FUSE to mount our bucket
    spec:
      serviceAccount: ... # <- our service account 
      containers:
         ...
        image:  ${IMAGE_NAME}  # <- image name with the app that we have previously built
        command: ["python3", "cmd/ingest_data.py"]   # <- run ingestion sctipt instead of a default entrypoint.
        env:
         ...
        - name: INPUT_DIR # <- Make ingestion script look into mounted FUSE directory
          value: /datalake
        volumeMounts: # <- same as with Ollama mount. Mount bucket where we put ingestion data
        - name: datalake
          mountPath: /datalake
      volumes:
      - name: datalake
        csi:
          driver: gcsfuse.csi.storage.gke.io
          volumeAttributes:
            bucketName: ...   # <- our bucket name
            mountOptions: implicit-dirs,only-dir=datalake # <- use another folder of a same bucket 
      ...
```

</details>

3. Wait for data to be ingested. It may take few minutes:

```
kubectl wait --for=condition=complete --timeout=600s job/llamaindex-ingest-data
```

4. Verify that data has been ingested:

```
kubectl logs -f -l name=ingest-data
```

Expected output:

```
Loaded 1 docs
Parsing nodes: 100%|██████████| 1/1 [00:00<00:00,  9.01it/s]
Generating embeddings: 100%|██████████| 21/21 [00:22<00:00,  1.05s/it]
Ingested 21 Nodes
```

*NOTE: The job's pod might not be available to check if you wait too long, as Kubernetes can delete completed jobs after a period of time.*

## 5.  Deploy RAG server

1. Apply created manifest:

```
kubectl apply -f ../gen/rag-deployment.yaml
```

<details>
<summary>Key notes on the 'rag-deployment.yaml' file: </summary>


```
apiVersion: apps/v1
kind: Deployment
...
spec:
  ...
  template:
    ...
    spec:
      containers:
        - name: llamaindex-rag
          image:  ${IMAGE_NAME} # <- image name with the app that we have previously built
          ...
          env:
- name: MODEL_NAME # <- LMM name to use, gemma2:9b in our case 
		  ...          
- name: OLLAMA_SERVER_URL  # <- URL to connect to previously deployed Ollama server
              value: http://ollama-service:11434
          ...
```

</details>

2. Wait for deployment is completed:

```
kubectl rollout status deployment/llamaindex-rag
```

# Test the RAG

1. Forward port to get access from a local machine:

```
kubectl  port-forward svc/llamaindex-rag-service 8000:8000
```

   

2. Go to the [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs). You will see a single API endpoint where you can invoke a RAG system.

   

3. Do some prompting. If you ask `What Paul did?`, the output should look like this:

```
{
  "message": "He wrote essays and stories as a young person,  learned to program on an IBM 1401, and later moved on to microcomputers where he created games and programs like a word processor. He initially planned to study philosophy but switched to AI, influenced by a novel and a documentary about artificial intelligence. Paul focused on Lisp and even wrote a book about it called \"On Lisp\".  He explored computer science theory but found more excitement in building things. Eventually, he became interested in art and started taking classes at Harvard while still pursuing his PhD in computer science. He managed to write and submit a dissertation in time to graduate, utilizing parts of his work on \"On Lisp\". \n\n\n"
}
```

      

# Cleanup

```
terraform destroy -var-file=default_env.tfvars
```

# Troubleshooting

* There may be a temporary error in the pods, where we mount buckets by using FUSE. Normally, they should be resolved without any additional actions.

```
MountVolume.SetUp failed for volume "rag-ingest-data" : kubernetes.io/csi: mounter.SetUpAt failed to get CSI client: driver name gcsfuse.csi.storage.gke.io not found in the list of registered CSI drivers
```
