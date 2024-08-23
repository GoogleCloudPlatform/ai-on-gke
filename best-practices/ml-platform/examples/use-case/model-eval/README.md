# Model evaluation and validation

Once a model has completed fine-tuning, the model must be validated for precision and accuracy
against the dataset used to fine-tune the model. In this example, the model is deployed on an
inference serving engine to host the model for the model validaiton to take place. Two steps are performed
for this activity, the first is to send prompts to the fine-tuned model, the second is to validate the results.

## Prerequisites

- This guide was developed to be run on the [playground machine learning platform](/best-practices/ml-platform/examples/platform/playground/README.md). If you are using a different environment the scripts and manifest will need to be modified for that environment.
- A bucket containing the model weights from the [Fine tuning example](../../fine-tuning/pytorch)

## Preparation

- Clone the repository and change directory to the guide directory

  ```
  git clone https://github.com/GoogleCloudPlatform/ai-on-gke && \
  cd ai-on-gke/best-practices/ml-platform/examples/use-case/model-eval
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

- Set `DATA_BUCKET` to the name of your Google Cloud Storage (GCS) bucket where the data from [Data Preparation](../../data-processing/ray) and [Data Preparation](../../data-preparation/gemma-it) is stored

  ```
  DATA_BUCKET=
  ```

- Set `MODEL_BUCKET` to the name of your Google Cloud Storage (GCS) bucket where the data from [Fine tuning](../../fine-tuning/pytorch) model is stored

  ```
  MODEL_BUCKET=
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
  DOCKER_IMAGE_URL="us-docker.pkg.dev/${PROJECT_ID}/llm-finetuning/validate:v1.0.0"
  ```

## Configuration

- Setup Workload Identity Federation access the buckets

  ```sh
  gcloud storage buckets add-iam-policy-binding gs://${DATA_BUCKET} \
  --member "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA}" \
  --role "roles/storage.objectUser"
  ```

  ```sh
  gcloud storage buckets add-iam-policy-binding gs://${DATA_BUCKET} \
  --member "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA}" \
  --role "roles/storage.legacyBucketWriter"
  ```

  ```sh
  gcloud storage buckets add-iam-policy-binding gs://${MODEL_BUCKET} \
  --member "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA}" \
  --role "roles/storage.objectUser"
  ```

## Build the container image

- Create Artifact Registry repository for your docker image

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

- Build container image using Cloud Build and push the image to Artifact Registry

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

- Create the Kubernetes Service Account (KSA) [optional if one, does not already exist]

  ```sh
  kubectl create serviceaccount ${KSA} -n ${NAMESPACE}
  ```

- Configure the deployment

  | Variable       | Description                                     | Example                                  |
  | -------------- | ----------------------------------------------- | ---------------------------------------- |
  | VLLM_IMAGE_URL | The image url for the vllm image                | vllm/vllm-openai:v0.5.3.post1            |
  | MODEL          | The output folder path for the fine-tuned model | /model-data/model-gemma2-a100/experiment |

  ```sh
  VLLM_IMAGE_URL="vllm/vllm-openai:v0.5.3.post1"
  MODEL="/model-data/model-gemma2/experiment"
  ```

  ```sh
  sed \
  -i -e "s|V_IMAGE_URL|${VLLM_IMAGE_URL}|" \
  -i -e "s|V_KSA|${KSA}|" \
  -i -e "s|V_BUCKET|${MODEL_BUCKET}|" \
  -i -e "s|V_MODEL_PATH|${MODEL}|" \
  manifests/deployment.yaml
  ```

- Create the deployment

  ```sh
  kubectl --namespace ${NAMESPACE} apply -f manifests/deployment.yaml
  ```

- Wait for the deployment to be ready

- Configure the job

  | Variable            | Description                                                                                               | Example                                     |
  | ------------------- | --------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
  | DATASET_OUTPUT_PATH | The folder path of the generated output data set.                                                         | dataset/output                              |
  | ENDPOINT            | This is the endpoint URL of the inference server                                                          | http://vllm-openai:8000/v1/chat/completions |
  | MODEL_PATH          | The output folder path for the fine-tuned model. This is used by model evaluation to generate the prompt. | /model-data/model-gemma2/experiment         |
  | PREDICTIONS_FILE    | The predictions file                                                                                      | predictions.txt                             |

  ```sh
  DATASET_OUTPUT_PATH="dataset/output"
  ENDPOINT="http://vllm-openai:8000/v1/chat/completions"
  MODEL_PATH="/model-data/model-gemma2/experiment"
  PREDICTIONS_FILE="predictions.txt"
  ```

  ```sh
  sed \
  -i -e "s|V_DATA_BUCKET|${DATA_BUCKET}|" \
  -i -e "s|V_DATASET_OUTPUT_PATH|${DATASET_OUTPUT_PATH}|" \
  -i -e "s|V_ENDPOINT|${ENDPOINT}|" \
  -i -e "s|V_IMAGE_URL|${DOCKER_IMAGE_URL}|" \
  -i -e "s|V_KSA|${KSA}|" \
  -i -e "s|V_MODEL_PATH|${MODEL_PATH}|" \
  -i -e "s|V_PREDICTIONS_FILE|${PREDICTIONS_FILE}|" \
  manifests/job.yaml
  ```

- Create the job

  ```sh
  kubectl --namespace ${NAMESPACE} apply -f manifests/job.yaml
  ```
