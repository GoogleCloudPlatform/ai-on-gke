# Data Processing

Preprocessed flipkart product catalog data is used as input data to generate prompts in preparation for fine-tuning.
The prompts are generated using Vertex AI's Gemini Flash model. The output is a data set that can be used for fine-tuning
the base model.


## Preparation
- Environment Variables
```
PROJECT_ID=gkebatchexpce3c8dcb
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
BUCKET=kh-finetune-ds1
NAMESPACE=ml-team
KSA=ray-worker
```

- Create the bucket for storing the training data set
```
gcloud storage buckets create gs://${BUCKET} \
    --project ${PROJECT_ID} \
    --location us
```

- Setup Workload Identity Federation access to read/write to the bucket
```
gcloud storage buckets add-iam-policy-binding gs://${BUCKET} \
    --member "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA}" \
    --role "roles/storage.objectUser"
```

- The Kubernetes Service Account user will need access to Vertex AI
```
gcloud projects add-iam-policy-binding projects/${PROJECT_ID} \
    --member=principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA} \
    --role=roles/aiplatform.user \
    --condition=None
```

## Build the image of the source
- Modify cloudbuild.yaml to specify the image url
```
gcloud builds submit . --project ${PROJECT_ID}
```

## Data Prepraration Job inputs
| Variable | Description | Example |
| --- | --- | --- |
| BUCKET | The bucket used for input and output. | kh-finetune-ds | 
| DATASET_INPUT_PATH | The folder path of where the preprocessed flipkart data resides | flipkart_preprocessed_dataset |
| DATASET_INPUT_FILE | The filename of the preprocessed flipkart data | flipkart.csv |
| DATASET_OUTPUT_PATH | The folder path of where the generated output data set will reside. This path will be needed for fine-tuning. | dataset/output |
| PROJECT_ID | The Project ID for the Vertex AI API | |
| PROMPT_MODEL_ID | The Vertex AI model for prompt generation | gemini-1.5-flash-001 |
| VERTEX_REGION | The region for the Vertex AI API | |
