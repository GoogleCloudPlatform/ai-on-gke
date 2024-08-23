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

- Ensure that your `MLP_ENVIRONMENT_FILE` is configured

  ```
  cat ${MLP_ENVIRONMENT_FILE} && \
  source ${MLP_ENVIRONMENT_FILE}
  ```

  > You should see the various variables populated with the information specific to your environment.

### Vertex AI variables

- Set `REGION` to Google Cloud region to use for the Vertex AI API calls

  ```
  REGION=us-central1
  ```

## Build the container image

- Build the container image using Cloud Build and push the image to Artifact Registry

  ```
  cd src
  gcloud builds submit --config cloudbuild.yaml \
  --project ${MLP_PROJECT_ID} \
  --substitutions _DESTINATION=${MLP_DATA_PREPARATION_IMAGE}
  cd ..
  ```

## Run the job

- Get credentials for the GKE cluster

  ```sh
  gcloud container fleet memberships get-credentials ${MLP_CLUSTER_NAME} --project ${MLP_PROJECT_ID}
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
  -i -e "s|V_IMAGE_URL|${MLP_DATA_PREPARATION_IMAGE}|" \
  -i -e "s|V_KSA|${MLP_DATA_PREPARATION_KSA}|" \
  -i -e "s|V_PROJECT_ID|${MLP_PROJECT_ID}|" \
  -i -e "s|V_DATA_BUCKET|${MLP_DATA_BUCKET}|" \
  -i -e "s|V_DATASET_INPUT_PATH|${DATASET_INPUT_PATH}|" \
  -i -e "s|V_DATASET_INPUT_FILE|${DATASET_INPUT_FILE}|" \
  -i -e "s|V_DATASET_OUTPUT_PATH|${DATASET_OUTPUT_PATH}|" \
  -i -e "s|V_PROMPT_MODEL_ID|${PROMPT_MODEL_ID}|" \
  -i -e "s|V_REGION|${REGION}|" \
  manifests/job.yaml
  ```

- Create the job

  ```sh
  kubectl --namespace ${MLP_KUBERNETES_NAMESPACE} apply -f manifests/job.yaml
  ```

- Once the Job is completed, the prepared datasets are stored in Google Cloud Storage.

  ```sh
  gcloud storage ls gs://${MLP_DATA_BUCKET}/${DATASET_OUTPUT_PATH}
  ```
