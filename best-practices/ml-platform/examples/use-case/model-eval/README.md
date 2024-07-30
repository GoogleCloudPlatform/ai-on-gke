# Model evaluation and validation

Once a model has completed fine-tuning, the model must be validated for precision and accuracy
against the dataset used to fine-tune the model. In this example, the model is deployed on an 
inference serving engine to host the model for the model validaiton to take place.  Two steps are performed
for this activity, the first is to send prompts to the fine-tuned model, the second is to validate the results.

## Preparation
- Environment Variables
```
PROJECT_ID=<your-project-id>
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
TRAINING_DATASET_BUCKET=<training-dataset-bucket-name>
V_MODEL_BUCKET=<model-artifacts-bucket>
CLUSTER_NAME=<your-gke-cluster>
NAMESPACE=ml-team
KSA=<k8s-service-account>
DOCKER_IMAGE_URL=us-docker.pkg.dev/${PROJECT_ID}/llm-finetuning/validate:v1.0.0
```

# GCS
The training data set is retrieved from a storage bucket and the fine-tuned model weights are saved onto a locally mounted storage bucket.

- Setup Workload Identity Federation access to read/write to the bucket for the training data set.
```
gcloud storage buckets add-iam-policy-binding gs://${TRAINING_DATASET_BUCKET} \
    --member "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA}" \
    --role "roles/storage.objectUser"
```

```
gcloud storage buckets add-iam-policy-binding gs://${TRAINING_DATASET_BUCKET} \
    --member "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA}" \
    --role "roles/storage.legacyBucketWriter"
```

- Setup Workload Identity Federation access to read from the bucket for the model weights, for vLLM
```
gcloud storage buckets add-iam-policy-binding gs://${V_MODEL_BUCKET} \
    --member "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA}" \
    --role "roles/storage.objectUser"
```

## Build the image of the source

Create Artifact Registry repository for your docker image
```
gcloud artifacts repositories create llm-finetuning \
--repository-format=docker \
--location=us \
--project=${PROJECT_ID} \
--async
```

Enable the Cloud Build APIs
```
gcloud services enable cloudbuild.googleapis.com --project ${PROJECT_ID}
```
    
Build container image using Cloud Build and push the image to Artifact Registry
Modify cloudbuild.yaml to specify the image url
      
```
sed -i "s|IMAGE_URL|${DOCKER_IMAGE_URL}|" cloudbuild.yaml && \
gcloud builds submit . --project ${PROJECT_ID}
```

Get credentials for the GKE cluster

```
gcloud container fleet memberships get-credentials ${CLUSTER_NAME} --project ${PROJECT_ID}
```

## Model evaluation Job inputs

- For `vllm-openai.yaml`

| Variable | Description | Example |
| --- | --- | --- |
| IMAGE_URL | The image url for the vllm image | |
| MODEL | The output folder path for the fine-tuned model | /model-data/model-gemma2-a100/experiment |
| V_BUCKET | The bucket where the model weights are located | |

```
VLLM_IMAGE_URL=""
BUCKET=""
MODEL="/model-data/model-gemma2-a100/experiment"
```

```
sed -i -e "s|IMAGE_URL|${VLLM_IMAGE_URL}|" \
   -i -e "s|KSA|${KSA}|" \
   -i -e "s|V_BUCKET|${BUCKET}|" \
   -i -e "s|V_MODEL_PATH|${MODEL}|" \
   vllm-openai.yaml
```
Create the Job in the “ml-team” namespace using kubectl command

```
kubectl apply -f vllm-openai.yaml -n ml-team
```

- For `model-eval.yaml`
  
| Variable | Description | Example |
| --- | --- | --- |
| IMAGE_URL | The image url of the validate image | |
| BUCKET | The bucket where the fine-tuning data set is located | | 
| MODEL_PATH | The output folder path for the fine-tuned model.  This is used by model evaluation to generate the prompt. | /model-data/model-gemma2-a100/experiment |
| DATASET_OUTPUT_PATH | The folder path of the generated output data set. | dataset/output |
| ENDPOINT | This is the endpoint URL of the inference server | http://10.40.0.51:8000/v1/chat/completions | 

```
BUCKET="<fine-tuning-dataset-bucket>"
MODEL_PATH=""
DATASET_OUTPUT_PATH=""
ENDPOINT="http://vllm-openai:8000/v1/chat/completions"
```
```
sed -i -e "s|IMAGE_URL|${DOCKER_IMAGE_URL}|" \
   -i -e "s|KSA|${KSA}|" \
   -i -e "s|V_BUCKET|${BUCKET}|" \
   -i -e "s|V_MODEL_PATH|${MODEL_PATH}|" \
   -i -e "s|V_DATASET_OUTPUT_PATH|${DATASET_OUTPUT_PATH}|" \
   -i -e "s|V_ENDPOINT|${ENDPOINT}|" \
   model-eval.yaml
```

Create the Job in the `ml-team` namespace using kubectl command

```
kubectl apply -f model-eval.yaml -n ml-team
```
