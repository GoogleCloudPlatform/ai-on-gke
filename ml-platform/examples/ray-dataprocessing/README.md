# Distributed Data Processing with Ray on GKE

## Dataset
This is a pre-crawled public dataset, taken as a subset of a bigger dataset (more than 5.8 million products) that was created by extracting data from Flipkart, a leading Indian eCommerce store.

## Architecture
 ![DataPreprocessing](/ml-platform/docs/images/DataPreprocessing.png)

## Data processing steps

The dataset has product information such as id, name, brand, description, image urls, product specifications. 

The preprocessing.py file does the following:
* Read the csv from Cloud Storage
* Clean up the product description text
* Extract image urls, validate and download the images into cloud storage
* Cleanup & extract attributes as key-value pairs

## How to use this repo:

1. Set environment variables

```
  PROJECT_ID=<your_project_id>
  PROCESSING_BUCKET=<your_bucket_name>
  DOCKER_IMAGE_URL=us-docker.pkg.dev/${PROJECT_ID}/dataprocessing/dp:v0.0.1
```


2. Create a Cloud Storage bucket to store raw data

```
 gcloud storage buckets create gs://${PROCESSING_BUCKET} --project ${PROJECT_ID}
```


3. Download the raw data csv file from above and store into the bucket created in the previous step.
   The kaggle cli can be installed using the following instructions
   To use the cli you must create an API token (Kaggle > User Profile > API > Create New Token), the downloaded file should be stored in HOME/.kaggle/kaggle.json.
   Alternatively, it can be downloaded from the kaggle website

```
 kaggle datasets download --unzip atharvjairath/flipkart-ecommerce-dataset
 gcloud storage cp flipkart_com-ecommerce_sample.csv \
 gs://${PROCESSING_BUCKET}/flipkart_raw_dataset/flipkart_com-ecommerce_sample.csv
```

4. Provide respective GCS bucket access rights to GKE Kubernetes Service Accounts.
   Ray head with access to read the raw source data in the storage bucket
   Ray worker(s) with the access to write data to the storage bucket.

```
 gcloud projects add-iam-policy-binding ${PROJECT_ID} \
 --member "serviceAccount:wi-ml-team-ray-head@${PROJECT_ID}.iam.gserviceaccount.com" \
 --role roles/storage.objectViewer

 gcloud projects add-iam-policy-binding ${PROJECT_ID} \
 --member "serviceAccount:wi-ml-team-ray-worker@${PROJECT_ID}.iam.gserviceaccount.com" \
 --role roles/storage.objectAdmin
```

5. Create Artifact Registry repository for your docker image
```
 gcloud artifacts repositories create dataprocessing \
 --repository-format=docker \
 --location=us \
 --project=${PROJECT_ID} \
 --async
```

6. Build container image using Cloud Build and push the image to Artifact Registry
```
 gcloud builds submit . \
 --tag ${DOCKER_IMAGE_URL}:v0.0.1
```

7. Update respective variables in the Job submission manifest to reflect your configuration.
   a. Image is the docker image that was built in the previous step
   b. Processing bucket is the location of the GCS bucket where the source data and results will be stored
   c. Ray Cluster Host - if used in this example, it should not need to be changed, but if your Ray cluster service is named differently or in a different namespace, update accordingly.

```
sed -i 's|#IMAGE|${DOCKER_IMAGE_URL}:v0.0.1' job.yaml
sed -i 's|#PROCESSING_BUCKET|${PROCESSING_BUCKET}' job.yaml
```

8. Create the Job in the “ml-team” namespace using kubectl command

```
kubectl apply -f job.yaml -n ml-team
```

9. Monitor the execution in Ray Dashboard
    a. Jobs -> Running Job ID
     i) See the Tasks/actors overview for Running jobs
     ii) See the Task Table for a detailed view of task and assigned node(s)
    b. Cluster -> Node List
     i) See the Ray actors running on the worker process

11. Once the Job is completed, both the prepared dataset as a CSV and the images are stored in Google Cloud Storage.
```
 gcloud storage ls \
 gs://${PROCESSING_BUCKET}/flipkart_preprocessed_dataset/flipkart.csv

 gcloud storage ls \
 gs://${PROCESSING_BUCKET}/flipkart_images
```
