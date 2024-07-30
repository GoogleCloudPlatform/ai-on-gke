# Data Processing

Preprocessed flipkart product catalog data is used as input data to generate prompts in preparation for fine-tuning.
The prompts are generated using Vertex AI's Gemini Flash model. The output is a data set that can be used for fine-tuning
the base model.


## Steps

1. Clone the repository and change directory to the guide directory

   ```
   git clone https://github.com/GoogleCloudPlatform/ai-on-gke && \
   cd ai-on-gke/best-practices/ml-platform/examples/use-case/datapreparation/gemma-it
   ```

2. Set environment variables

    ```
    PROJECT_ID=<your_project_id>
    PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
    BUCKET=<your_bucket_name>
    NAMESPACE=ml-team
    KSA=<your-k8s-service-account>
    CLUSTER_NAME=<your_cluster_name>
    CLUSTER_REGION=<cluster-region>
    DOCKER_IMAGE_URL=us-docker.pkg.dev/${PROJECT_ID}/llm-finetuning/dataprep:v1.0.0
    VERTEX_REGION=<vertex-region>
   ```

3. Create the bucket for storing the prepared dataset

    ```
    gcloud storage buckets create gs://${BUCKET} \
        --project ${PROJECT_ID} \
        --location us \
        --uniform-bucket-level-access
    ```

4. Setup Workload Identity Federation access to read/write to the bucket

    ```
    gcloud storage buckets add-iam-policy-binding gs://${BUCKET} \
        --member "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA}" \
        --role "roles/storage.objectUser"
    ```

5. The Kubernetes Service Account user will need access to Vertex AI

    ```
    gcloud projects add-iam-policy-binding projects/${PROJECT_ID} \
        --member=principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA} \
        --role=roles/aiplatform.user \
        --condition=None
    ```

6. Create Artifact Registry repository for your docker image
    ```
    gcloud artifacts repositories create llm-finetuning \
    --repository-format=docker \
    --location=us \
    --project=${PROJECT_ID} \
    --async
    ```

7. Enable the Cloud Build APIs
    ```
    gcloud services enable cloudbuild.googleapis.com --project ${PROJECT_ID}
    ```
    
8. Build container image using Cloud Build and push the image to Artifact Registry
    - Modify cloudbuild.yaml to specify the image url
      

    ```
    sed -i "s|IMAGE_URL|${DOCKER_IMAGE_URL}|" cloudbuild.yaml && \
    gcloud builds submit . --project ${PROJECT_ID}
    ```

1. Get credentials for the GKE cluster

   ```
   gcloud container fleet memberships get-credentials ${CLUSTER_NAME} --project ${PROJECT_ID}
   ```

1. Update Data Preparation Job variables

   Data Prepraration Job inputs:
   | Variable | Description | Example |
   | --- | --- | --- |
   | BUCKET | The bucket used for input and output. | | 
   | DATASET_INPUT_PATH | The folder path of where the preprocessed flipkart data resides | flipkart_preprocessed_dataset |
   | DATASET_INPUT_FILE | The filename of the preprocessed flipkart data | flipkart.csv |
   | DATASET_OUTPUT_PATH | The folder path of where the generated output data set will reside. This path will be needed for fine-tuning. | dataset/output |
   | PROJECT_ID | The Project ID for the Vertex AI API | |
   | PROMPT_MODEL_ID | The Vertex AI model for prompt generation | gemini-1.5-flash-001 |
   | VERTEX_REGION | The region for the Vertex AI API | |

   Update respective variables in the dataprep job submission manifest to reflect your configuration.

   ``` 
   DATASET_INPUT_PATH="flipkart_preprocessed_dataset"
   DATASET_INPUT_FILE="flipkart.csv"
   DATASET_OUTPUT_PATH="dataset/output"
   PROMPT_MODEL_ID="gemini-1.5-flash-001"
   ```
   
   ``` 
   sed -i -e "s|IMAGE_URL|${DOCKER_IMAGE_URL}|" \
      -i -e "s|KSA|${KSA}|" \
      -i -e "s|V_PROJECT_ID|${PROJECT_ID}|" \
      -i -e "s|V_BUCKET|${BUCKET}|" \
      -i -e "s|V_DATASET_INPUT_PATH|${DATASET_INPUT_PATH}|" \
      -i -e "s|V_DATASET_INPUT_FILE|${DATASET_INPUT_FILE}|" \
      -i -e "s|V_DATASET_OUTPUT_PATH|${DATASET_OUTPUT_PATH}|" \
      -i -e "s|V_PROMPT_MODEL_ID|${PROMPT_MODEL_ID}|" \
      -i -e "s|V_VERTEX_REGION|${VERTEX_REGION}|" \
      dataprep.yaml

   ```

1. Create the Job in the “ml-team” namespace using kubectl command

   ``` 
   kubectl apply -f dataprep.yaml -n ml-team
   ```

1. Once the Job is completed, both the prepared datasets are stored in Google Cloud Storage.

   ```
   gcloud storage ls gs://${BUCKET}/${DATASET_OUTPUT_PATH}
   ```
