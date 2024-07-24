# Data Processing

Preprocessed flipkart product catalog data is used as input data to generate prompts in preparation for fine-tuning.
The prompts are generated using Vertex AI's Gemini Flash model. The output is a data set that can be used for fine-tuning
the base model.


## Preparation

1. Clone the repository and change directory to the guide directory

   ```
   git clone https://github.com/GoogleCloudPlatform/ai-on-gke && \
   cd ai-on-gke/best-practices/ml-platform/examples/use-case/finetuning/pytorch/dataprep
   ```

2. Set environment variables

    ```
    PROJECT_ID=<your_project_id>
    PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
    BUCKET=<your_bucket_name>
    NAMESPACE=ml-team
    KSA=<your-k8s-service-account>
    CLUSTER_NAME=<your_cluster_name>
    DOCKER_IMAGE_URL=us-docker.pkg.dev/${PROJECT_ID}/llm-finetuning/dataprep:v1.0.0
   ```

   ## Data Prepraration Job inputs
   | Variable | Description | Example |
   | --- | --- | --- |
   | BUCKET | The bucket used for input and output. | | 
   | DATASET_INPUT_PATH | The folder path of where the preprocessed flipkart data resides | flipkart_preprocessed_dataset |
   | DATASET_INPUT_FILE | The filename of the preprocessed flipkart data | flipkart.csv |
   | DATASET_OUTPUT_PATH | The folder path of where the generated output data set will reside. This path will be needed for fine-tuning. | dataset/output |
   | PROJECT_ID | The Project ID for the Vertex AI API | |
   | PROMPT_MODEL_ID | The Vertex AI model for prompt generation | gemini-1.5-flash-001 |
   | VERTEX_REGION | The region for the Vertex AI API | |

3. Create the bucket for storing the prepared dataset

    ```
    gcloud storage buckets create gs://${BUCKET} \
        --project ${PROJECT_ID} \
        --location us
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
    sed -i "s|#IMAGE|${DOCKER_IMAGE_URL}|" cloudbuild.yaml && \
    gcloud builds submit . --project ${PROJECT_ID}
    ```


9. Update respective variables in the Job submission manifest to reflect your configuration.

   - Image is the docker image that was built in the previous step
   - Processing bucket is the location of the GCS bucket where the source data and results will be stored

   ```
   sed -i "s|#IMAGE|${DOCKER_IMAGE_URL}|" job.yaml && \
   sed -i "s|#BUCKET|${BUCKET}|" job.yaml
   ```

1. Get credentials for the GKE cluster

   ```
   gcloud container fleet memberships get-credentials ${CLUSTER_NAME} --project ${PROJECT_ID}
   ```

1. Create the Job in the “ml-team” namespace using kubectl command

   ```
   kubectl apply -f dataprep.yaml
   ```


1. Once the Job is completed, both the prepared datasets are stored in Google Cloud Storage.

   ```
   gcloud storage ls gs://${BUCKET}/flipkart_preprocessed_dataset/flipkart.csv
   gcloud storage ls gs://${BUCKET}/flipkart_images
   ```
   

