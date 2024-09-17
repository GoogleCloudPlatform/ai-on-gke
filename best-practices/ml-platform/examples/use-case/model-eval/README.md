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

- Ensure that your `MLP_ENVIRONMENT_FILE` is configured

  ```
  cat ${MLP_ENVIRONMENT_FILE} && \
  source ${MLP_ENVIRONMENT_FILE}
  ```

  > You should see the various variables populated with the information specific to your environment.

## Build the container image

- Build container image using Cloud Build and push the image to Artifact Registry

  ```
  cd src
  sed -i -e "s|^serviceAccount:.*|serviceAccount: projects/${MLP_PROJECT_ID}/serviceAccounts/${MLP_BUILD_GSA}|" cloudbuild.yaml
  gcloud beta builds submit --config cloudbuild.yaml \
  --project ${MLP_PROJECT_ID} \
  --substitutions _DESTINATION=${MLP_MODEL_EVALUATION_IMAGE}
  cd ..
  ```

## Run the job

- Get credentials for the GKE cluster

  ```sh
  gcloud container fleet memberships get-credentials ${MLP_CLUSTER_NAME} --project ${MLP_PROJECT_ID}
  ```

- Configure the deployment

  | Variable       | Description                                     | Example                                  |
  | -------------- | ----------------------------------------------- | ---------------------------------------- |
  | ACCELERATOR    | Type of GPU accelerator to use (l4, a100)       | l4                                       |
  | VLLM_IMAGE_URL | The image url for the vllm image                | vllm/vllm-openai:v0.5.3.post1            |
  | MODEL          | The output folder path for the fine-tuned model | /model-data/model-gemma2-a100/experiment |

  ```sh
  ACCELERATOR="l4"
  VLLM_IMAGE_URL="vllm/vllm-openai:v0.5.3.post1"
  MODEL="/model-data/model-gemma2/experiment"
  ```

  ```sh
  sed \
  -i -e "s|V_IMAGE_URL|${VLLM_IMAGE_URL}|" \
  -i -e "s|V_KSA|${MLP_MODEL_EVALUATION_KSA}|" \
  -i -e "s|V_BUCKET|${MLP_MODEL_BUCKET}|" \
  -i -e "s|V_MODEL_PATH|${MODEL}|" \
  manifests/deployment-${ACCELERATOR}.yaml
  ```

- Create the deployment

  ```sh
  kubectl --namespace ${MLP_KUBERNETES_NAMESPACE} apply -f manifests/deployment-${ACCELERATOR}.yaml
  ```

- Wait for the deployment to be ready

  ```
  kubectl --namespace ${MLP_KUBERNETES_NAMESPACE} wait --for=condition=ready --timeout=900s pod -l app=vllm-openai
  ```

  When they deployment is ready your should see output similar to:

  ```output
  pod/vllm-openai-XXXXXXXXXX-XXXXX condition met
  ```

- Configure the job

  | Variable            | Description                                                                                               | Example                                        |
  | ------------------- | --------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
  | DATASET_OUTPUT_PATH | The folder path of the generated output data set.                                                         | dataset/output                                 |
  | ENDPOINT            | This is the endpoint URL of the inference server                                                          | http://vllm-openai-l4:8000/v1/chat/completions |
  | MODEL_PATH          | The output folder path for the fine-tuned model. This is used by model evaluation to generate the prompt. | /model-data/model-gemma2/experiment            |
  | PREDICTIONS_FILE    | The predictions file                                                                                      | predictions.txt                                |

  ```sh
  DATASET_OUTPUT_PATH="dataset/output"
  ENDPOINT="http://vllm-openai-${ACCELERATOR}:8000/v1/chat/completions"
  MODEL_PATH="/model-data/model-gemma2/experiment"
  PREDICTIONS_FILE="predictions.txt"
  ```

  ```sh
  sed \
  -i -e "s|V_DATA_BUCKET|${MLP_DATA_BUCKET}|" \
  -i -e "s|V_DATASET_OUTPUT_PATH|${DATASET_OUTPUT_PATH}|" \
  -i -e "s|V_ENDPOINT|${ENDPOINT}|" \
  -i -e "s|V_IMAGE_URL|${MLP_MODEL_EVALUATION_IMAGE}|" \
  -i -e "s|V_KSA|${MLP_MODEL_EVALUATION_KSA}|" \
  -i -e "s|V_MODEL_PATH|${MODEL_PATH}|" \
  -i -e "s|V_PREDICTIONS_FILE|${PREDICTIONS_FILE}|" \
  manifests/job.yaml
  ```

- Create the job

  ```sh
  kubectl --namespace ${MLP_KUBERNETES_NAMESPACE} apply -f manifests/job.yaml
  ```
