# Model evaluation and validation

Once a model has completed fine-tuning, the model must be validated for precision and accuracy
against the dataset used to fine-tune the model. In this example, the model is deployed on an
inference serving engine to host the model for the model validaiton to take place. Two steps are performed
for this activity, the first is to send prompts to the fine-tuned model, the second is to validate the results.

## Prerequisites

- The [ML Platform Playground](../../../platform/playground) must be deployed
- Model weights from the [Fine tuning example](../../finetuning/pytorch)

## Preparation

- Clone the repository and change directory to the guide directory

  ```
  git clone https://github.com/GoogleCloudPlatform/ai-on-gke && \
  cd ai-on-gke/best-practices/ml-platform/examples/use-case/model-eval
  ```

- Environment Variables

  ```sh
  PROJECT_ID=<your-project-id>
  PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
  DATA_BUCKET=<training-dataset-bucket-name>
  MODEL_BUCKET=<model-artifacts-bucket>
  CLUSTER_NAME=<your-gke-cluster>
  NAMESPACE=ml-team
  KSA=<k8s-service-account>
  DOCKER_IMAGE_URL=us-docker.pkg.dev/${PROJECT_ID}/llm-finetuning/validate:v1.0.0
  ```

- Create the Kubernetes Service Account (KSA) [optional if one, does not already exist]

  ```sh
  kubectl create serviceaccount ${KSA} -n ${NAMESPACE}
  ```

### GCS

The training data set is retrieved from a storage bucket and the fine-tuned model weights are saved onto a locally mounted storage bucket.

- Setup Workload Identity Federation access to read/write to the bucket for the training data set.

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

- Setup Workload Identity Federation access to read from the bucket for the model weights, for vLLM

  ```sh
  gcloud storage buckets add-iam-policy-binding gs://${MODEL_BUCKET} \
      --member "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA}" \
      --role "roles/storage.objectUser"
  ```

## Build the image of the source

Create Artifact Registry repository for your docker image

```sh
gcloud artifacts repositories create llm-finetuning \
    --repository-format=docker \
    --location=us \
    --project=${PROJECT_ID} \
    --async
```

Enable the Cloud Build APIs

```sh
gcloud services enable cloudbuild.googleapis.com --project ${PROJECT_ID}
```

Build container image using Cloud Build and push the image to Artifact Registry

```
cd src
gcloud builds submit --config cloudbuild.yaml \
--project ${PROJECT_ID} \
--substitutions _DESTINATION=${DOCKER_IMAGE_URL}
cd ..
```

Get credentials for the GKE cluster

```sh
gcloud container fleet memberships get-credentials ${CLUSTER_NAME} --project ${PROJECT_ID}
```

## Model evaluation Job inputs

- For `vllm-openai.yaml`

| Variable     | Description                                     | Example                                  |
| ------------ | ----------------------------------------------- | ---------------------------------------- |
| IMAGE_URL    | The image url for the vllm image                |                                          |
| MODEL        | The output folder path for the fine-tuned model | /model-data/model-gemma2-a100/experiment |
| MODEL_BUCKET | The bucket where the model weights are located  |                                          |

```sh
VLLM_IMAGE_URL=""
MODEL_BUCKET=""
MODEL="/model-data/model-gemma2-a100/experiment"
```

```sh
sed -i -e "s|V_IMAGE_URL|${VLLM_IMAGE_URL}|" \
    -i -e "s|V_KSA|${KSA}|" \
    -i -e "s|V_BUCKET|${MODEL_BUCKET}|" \
    -i -e "s|V_MODEL_PATH|${MODEL}|" \
    vllm-openai.yaml
```

Create the Job in the `ml-team` namespace using kubectl command

```sh
kubectl apply -f vllm-openai.yaml -n ml-team
```

- For `model-eval.yaml`

| Variable            | Description                                                                                               | Example                                      |
| ------------------- | --------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| IMAGE_URL           | The image url of the validate image                                                                       |                                              |
| DATA_BUCKET         | The bucket where the fine-tuning data set is located                                                      |                                              |
| MODEL_PATH          | The output folder path for the fine-tuned model. This is used by model evaluation to generate the prompt. | /model-data/model-gemma2-a100/experiment     |
| DATASET_OUTPUT_PATH | The folder path of the generated output data set.                                                         | dataset/output                               |
| ENDPOINT            | This is the endpoint URL of the inference server                                                          | <http://10.40.0.51:8000/v1/chat/completions> |

```sh
DATA_BUCKET="<fine-tuning-dataset-bucket>"
MODEL_PATH=""
DATASET_OUTPUT_PATH=""
ENDPOINT="http://vllm-openai:8000/v1/chat/completions"
```

```sh
sed -i -e "s|V_IMAGE_URL|${DOCKER_IMAGE_URL}|" \
    -i -e "s|V_KSA|${KSA}|" \
    -i -e "s|V_DATA_BUCKET|${DATA_BUCKET}|" \
    -i -e "s|V_MODEL_PATH|${MODEL_PATH}|" \
    -i -e "s|V_DATASET_OUTPUT_PATH|${DATASET_OUTPUT_PATH}|" \
    -i -e "s|V_ENDPOINT|${ENDPOINT}|" \
    model-eval.yaml
```

Create the Job in the `ml-team` namespace using kubectl command

```sh
kubectl apply -f model-eval.yaml -n ml-team
```
