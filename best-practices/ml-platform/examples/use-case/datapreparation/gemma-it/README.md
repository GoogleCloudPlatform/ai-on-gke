# Data Processing

Preprocessed flipkart product catalog data is used as input data to generate prompts in preparation for fine-tuning.
The prompts are generated using Vertex AI's Gemini Flash model. The output is a data set that can be used for fine-tuning
the base model.

## Prerequisites

- The [ML Platform Playground](../../../platform/playground) must be deployed
- Data output from the [Data Preprocessing example](../../datapreprocessing)

## Steps

1. Clone the repository and change directory to the guide directory

   ```sh
   git clone https://github.com/GoogleCloudPlatform/ai-on-gke && \
   cd ai-on-gke/best-practices/ml-platform/examples/use-case/datapreparation/gemma-it
   ```

1. Set environment variables

   ```sh
   PROJECT_ID=<your_project_id>
   PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
   BUCKET=<preprocessed_dataset_bucket_name>
   NAMESPACE=ml-team
   KSA=<your-k8s-service-account>
   CLUSTER_NAME=<your_cluster_name>
   DOCKER_IMAGE_URL=us-docker.pkg.dev/${PROJECT_ID}/llm-finetuning/dataprep:v1.0.0
   REGION=<vertex-region>
   ```

1. Create the Kubernetes Service Account (KSA) [optional if one, does not already exist]

   ```sh
   kubectl create serviceaccount ${KSA} -n ${NAMESPACE}
   ```

1. Setup Workload Identity Federation access to read/write to the bucket

   ```sh
   gcloud storage buckets add-iam-policy-binding gs://${BUCKET} \
       --member "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA}" \
       --role "roles/storage.objectUser"
   ```

1. The Kubernetes Service Account user will need access to Vertex AI

   ```sh
   gcloud projects add-iam-policy-binding projects/${PROJECT_ID} \
       --member=principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA} \
       --role=roles/aiplatform.user \
       --condition=None
   ```

1. Create Artifact Registry repository for your docker image

   ```sh
   gcloud artifacts repositories create llm-finetuning \
   --repository-format=docker \
   --location=us \
   --project=${PROJECT_ID} \
   --async
   ```

1. Enable the Cloud Build APIs

   ```sh
   gcloud services enable cloudbuild.googleapis.com --project ${PROJECT_ID}
   ```

1. Build container image using Cloud Build and push the image to Artifact Registry

   - Modify cloudbuild.yaml to specify the image url

      ```sh
      sed -i "s|IMAGE_URL|${DOCKER_IMAGE_URL}|" cloudbuild.yaml && \
      gcloud builds submit . --project ${PROJECT_ID}
      ```

1. Get credentials for the GKE cluster

   ```sh
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
   | REGION | The region for the Vertex AI API | |

   Update respective variables in the dataprep job submission manifest to reflect your configuration.

   ```sh
   DATASET_INPUT_PATH="flipkart_preprocessed_dataset"
   DATASET_INPUT_FILE="flipkart.csv"
   DATASET_OUTPUT_PATH="dataset/output/"
   PROMPT_MODEL_ID="gemini-1.5-flash-001"
   ```

   ```sh
   sed -i -e "s|IMAGE_URL|${DOCKER_IMAGE_URL}|" \
      -i -e "s|KSA|${KSA}|" \
      -i -e "s|V_PROJECT_ID|${PROJECT_ID}|" \
      -i -e "s|V_BUCKET|${BUCKET}|" \
      -i -e "s|V_DATASET_INPUT_PATH|${DATASET_INPUT_PATH}|" \
      -i -e "s|V_DATASET_INPUT_FILE|${DATASET_INPUT_FILE}|" \
      -i -e "s|V_DATASET_OUTPUT_PATH|${DATASET_OUTPUT_PATH}|" \
      -i -e "s|V_PROMPT_MODEL_ID|${PROMPT_MODEL_ID}|" \
      -i -e "s|V_REGION|${REGION}|" \
      dataprep.yaml
   ```

1. Create the Job in the “ml-team” namespace using kubectl command

   ```sh
   kubectl apply -f dataprep.yaml -n ml-team
   ```

1. Once the Job is completed, both the prepared datasets are stored in Google Cloud Storage.

   ```sh
   gcloud storage ls gs://${BUCKET}/${DATASET_OUTPUT_PATH}
   ```
