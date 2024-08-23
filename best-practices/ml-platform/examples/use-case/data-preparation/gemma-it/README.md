# Data Preparation

A processed flipkart product catalog data is used as input data to generate prompts in preparation for fine-tuning.
The prompts are generated using Vertex AI's Gemini Flash model. The output is a data set that can be used for fine-tuning
the base model.

## Prerequisites

- This guide was developed to be run on the [playground machine learning platform](/best-practices/ml-platform/examples/platform/playground/README.md). If you are using a different environment the scripts and manifest will need to be modified for that environment.
- A bucket containing the processed data from the [Data Processing example](../../data-processing/ray)

## Preparation

- Clone the repository and change directory to the guide directory

  ```sh
  git clone https://github.com/GoogleCloudPlatform/ai-on-gke && \
  cd ai-on-gke/best-practices/ml-platform/examples/use-case/data-preparation/gemma-it
  ```

### Project variables

- Set `PROJECT_ID` to the project ID of the project where your GKE cluster and other resources will reside

  ```
  PROJECT_ID=
  ```

- Populate `PROJECT_NUMBER` based on the `PROJECT_ID` environment variable

  ```
  PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
  ```

### GCS bucket variables

- Set `DATA_BUCKET` to the name of your Google Cloud Storage (GCS) bucket where the data from [Data Processing](../../data-processing/ray) is stored

  ```
  DATA_BUCKET=
  ```

### Kubernetes variables

- Set `NAMESPACE` to the Kubernetes namespace to be used

  ```
  NAMESPACE="ml-team"
  ```

- Set `KSA` to the Kubernetes service account to be used

  ```
  KSA="app-sa"
  ```

- Set `CLUSTER_NAME` to the name of your GKE cluster

  ```
  CLUSTER_NAME=
  ```

### Container image variables

- Set `DOCKER_IMAGE_URL` to the URL for the container image that will be created

  ```
  DOCKER_IMAGE_URL="us-docker.pkg.dev/${PROJECT_ID}/llm-finetuning/dataprep:v1.0.0"
  ```

### Vertex AI variables

- Set `REGION` to Google Cloud region to use for the Vertex AI API calls

  ```
  REGION=us-central1
  ```

## Configuration

- Setup Workload Identity Federation to access the bucket

  ```sh
  gcloud storage buckets add-iam-policy-binding gs://${DATA_BUCKET} \
  --member "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA}" \
  --role "roles/storage.objectUser"
  ```

- Setup Workload Identity Federation to access to Vertex AI

  ```sh
  gcloud projects add-iam-policy-binding projects/${PROJECT_ID} \
  --condition=None \
  --member=principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA} \
  --role=roles/aiplatform.user
  ```

## Build the container image

- Create the Artifact Registry repository for your container image

  ```sh
  gcloud artifacts repositories create llm-finetuning \
  --repository-format=docker \
  --location=us \
  --project=${PROJECT_ID} \
  --async
  ```

- Enable the Cloud Build APIs

  ```sh
  gcloud services enable cloudbuild.googleapis.com --project ${PROJECT_ID}
  ```

- Build the container image using Cloud Build and push the image to Artifact Registry

  ```
  cd src
  gcloud builds submit --config cloudbuild.yaml \
  --project ${PROJECT_ID} \
  --substitutions _DESTINATION=${DOCKER_IMAGE_URL}
  cd ..
  ```

## Run the job

- Get credentials for the GKE cluster

  ```sh
  gcloud container fleet memberships get-credentials ${CLUSTER_NAME} --project ${PROJECT_ID}
  ```

- Configure the job

  | Variable            | Description                                                                                                   | Example                       |
  | ------------------- | ------------------------------------------------------------------------------------------------------------- | ----------------------------- |
  | DATASET_INPUT_PATH  | The folder path of where the preprocessed flipkart data resides                                               | flipkart_preprocessed_dataset |
  | DATASET_INPUT_FILE  | The filename of the preprocessed flipkart data                                                                | flipkart.csv                  |
  | DATASET_OUTPUT_PATH | The folder path of where the generated output data set will reside. This path will be needed for fine-tuning. | dataset/output                |
  | PROMPT_MODEL_ID     | The Vertex AI model for prompt generation                                                                     | gemini-1.5-flash-001          |

  ```sh
  DATASET_INPUT_PATH="flipkart_preprocessed_dataset"
  DATASET_INPUT_FILE="flipkart.csv"
  DATASET_OUTPUT_PATH="dataset/output"
  PROMPT_MODEL_ID="gemini-1.5-flash-001"
  ```

  ```sh
  sed \
  -i -e "s|V_IMAGE_URL|${DOCKER_IMAGE_URL}|" \
  -i -e "s|V_KSA|${KSA}|" \
  -i -e "s|V_PROJECT_ID|${PROJECT_ID}|" \
  -i -e "s|V_DATA_BUCKET|${DATA_BUCKET}|" \
  -i -e "s|V_DATASET_INPUT_PATH|${DATASET_INPUT_PATH}|" \
  -i -e "s|V_DATASET_INPUT_FILE|${DATASET_INPUT_FILE}|" \
  -i -e "s|V_DATASET_OUTPUT_PATH|${DATASET_OUTPUT_PATH}|" \
  -i -e "s|V_PROMPT_MODEL_ID|${PROMPT_MODEL_ID}|" \
  -i -e "s|V_REGION|${REGION}|" \
  manifests/job.yaml
  ```

- Create the job

  ```sh
  kubectl --namespace ${NAMESPACE} apply -f manifests/job.yaml
  ```

- Once the Job is completed, the prepared datasets are stored in Google Cloud Storage.

  ```sh
  gcloud storage ls gs://${DATA_BUCKET}/${DATASET_OUTPUT_PATH}
  ```
