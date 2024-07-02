# Distributed Data Processing with Ray on GKE

## Dataset

[This](https://www.kaggle.com/datasets/PromptCloudHQ/flipkart-products) is a pre-crawled public dataset, taken as a subset of a bigger dataset (more than 5.8 million products) that was created by extracting data from [Flipkart](https://www.flipkart.com/), a leading Indian eCommerce store.

## Architecture

![DataPreprocessing](/best-practices/ml-platform/docs/images/ray-dataprocessing-workflow.png)

## Data processing steps

The dataset has product information such as id, name, brand, description, image urls, product specifications.

The preprocessing.py file does the following:

- Read the csv from Cloud Storage
- Clean up the product description text
- Extract image urls, validate and download the images into cloud storage
- Cleanup & extract attributes as key-value pairs

## How to use this repo:

1. Clone the repository and change directory to the guide directory

   ```
   git clone https://github.com/GoogleCloudPlatform/ai-on-gke && \
   cd ai-on-gke/best-practices/ml-platform/examples/use-case/ray/dataprocessing
   ```

1. Set environment variables

   ```
   CLUSTER_NAME=<your_cluster_name>
   PROJECT_ID=<your_project_id>
   PROCESSING_BUCKET=<your_bucket_name>
   DOCKER_IMAGE_URL=us-docker.pkg.dev/${PROJECT_ID}/dataprocessing/dp:v0.0.1
   ```

1. Create a Cloud Storage bucket to store raw data

   ```
   gcloud storage buckets create gs://${PROCESSING_BUCKET} --project ${PROJECT_ID} --uniform-bucket-level-access
   ```

1. Download the raw data csv file from above and store into the bucket created in the previous step.
   The kaggle cli can be installed using the following [instructions](https://github.com/Kaggle/kaggle-api#installation)
   To use the cli you must create an API token (Kaggle > User Profile > API > Create New Token), the downloaded file should be stored in HOME/.kaggle/kaggle.json.
   Alternatively, it can be [downloaded](https://www.kaggle.com/datasets/atharvjairath/flipkart-ecommerce-dataset) from the kaggle website

   ```
   kaggle datasets download --unzip atharvjairath/flipkart-ecommerce-dataset && \
   gcloud storage cp flipkart_com-ecommerce_sample.csv \
   gs://${PROCESSING_BUCKET}/flipkart_raw_dataset/flipkart_com-ecommerce_sample.csv && \
   rm flipkart_com-ecommerce_sample.csv
   ```

1. Provide respective GCS bucket access rights to GKE Kubernetes Service Accounts.
   Ray head with access to read the raw source data in the storage bucket
   Ray worker(s) with the access to write data to the storage bucket.

   ```
   gcloud projects add-iam-policy-binding ${PROJECT_ID} \
   --member "serviceAccount:${PROJECT_ID}.svc.id.goog[ml-team/ray-head]" \
   --role roles/storage.objectViewer

   gcloud projects add-iam-policy-binding ${PROJECT_ID} \
   --member "serviceAccount:${PROJECT_ID}.svc.id.goog[ml-team/ray-worker]" \ \
   --role roles/storage.objectAdmin
   ```

1. Create Artifact Registry repository for your docker image

   ```
   gcloud artifacts repositories create dataprocessing \
   --repository-format=docker \
   --location=us \
   --project=${PROJECT_ID} \
   --async
   ```

1. Enable the Cloud Build APIs

   ```
   gcloud services enable cloudbuild.googleapis.com --project ${PROJECT_ID}
   ```

1. Build container image using Cloud Build and push the image to Artifact Registry

   ```
   cd src && \
   gcloud builds submit \
   --project ${PROJECT_ID} \
   --tag ${DOCKER_IMAGE_URL} \
   . && \
   cd ..
   ```

1. Update respective variables in the Job submission manifest to reflect your configuration.

   - Image is the docker image that was built in the previous step
   - Processing bucket is the location of the GCS bucket where the source data and results will be stored
   - Ray Cluster Host - if used in this example, it should not need to be changed, but if your Ray cluster service is named differently or in a different namespace, update accordingly.

   ```
   sed -i "s|#IMAGE|${DOCKER_IMAGE_URL}|" job.yaml && \
   sed -i "s|#PROCESSING_BUCKET|${PROCESSING_BUCKET}|" job.yaml
   ```

1. Get credentials for the GKE cluster

   ```
   gcloud container fleet memberships get-credentials ${CLUSTER_NAME} --project ${PROJECT_ID}
   ```

1. Create the Job in the “ml-team” namespace using kubectl command

   ```
   kubectl apply -f job.yaml
   ```

1. Monitor the execution in Ray Dashboard

   - Jobs -> Running Job ID
     - See the Tasks/actors overview for Running jobs
     - See the Task Table for a detailed view of task and assigned node(s)
   - Cluster -> Node List
     - See the Ray actors running on the worker process

1. Once the Job is completed, both the prepared dataset as a CSV and the images are stored in Google Cloud Storage.

   ```
   gcloud storage ls gs://${PROCESSING_BUCKET}/flipkart_preprocessed_dataset/flipkart.csv
   gcloud storage ls gs://${PROCESSING_BUCKET}/flipkart_images
   ```

> For additional information about developing using this codebase see the [Developer Guide](DEVELOPER.md)

> For additional information about converting you code from a notebook to run as a Job on GKE see the [Conversion Guide](CONVERSION.md)
