#!/usr/bin/env bash

# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

start_runtime "dataprocessing"

echo_title "Preparing dataprocessing job"

echo_title "Enabling Artifact Registry APIs"

gcloud services enable artifactregistry.googleapis.com containerscanning.googleapis.com --project ${PROJECT_ID}

echo_title "Enabling Cloud Build APIs"

gcloud services enable cloudbuild.googleapis.com --project ${PROJECT_ID}

echo_title "Adding IAM permissions"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member "serviceAccount:wi-ml-team-ray-head@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/storage.objectViewer

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member "serviceAccount:wi-ml-team-ray-worker@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/storage.objectAdmin

echo_title "Creating GCS bucket"

gcloud storage buckets create gs://${PROCESSING_BUCKET} --project ${PROJECT_ID}

echo_title "Downloading the dataset and uploading to GCS"

print_and_execute "kaggle datasets download --unzip atharvjairath/flipkart-ecommerce-dataset && \
gcloud storage cp flipkart_com-ecommerce_sample.csv \
gs://${PROCESSING_BUCKET}/flipkart_raw_dataset/flipkart_com-ecommerce_sample.csv && \
rm flipkart_com-ecommerce_sample.csv"

echo_title "Creating Artifact Registry repository"

gcloud artifacts repositories create dataprocessing \
    --repository-format=docker \
    --location=us \
    --project=${PROJECT_ID}

echo_title "Building container image"

gcloud config set builds/use_kaniko True

while ! gcloud services list --project ${PROJECT_ID} | grep cloudbuild.googleapis.com >/dev/null 2>&1; do
    sleep 10
done

export MLP_USE_CASE_BASE_DIR="${MLP_BASE_DIR}/examples/use-case/ray/dataprocessing"
print_and_execute "cd ${MLP_USE_CASE_BASE_DIR}/src && \
gcloud builds submit \
--project ${PROJECT_ID} \
--tag ${DOCKER_IMAGE_URL} \
."
check_local_error_exit_on_error

echo_title "Configuring job"

sed -i "s|#IMAGE|${DOCKER_IMAGE_URL}|" ${MLP_USE_CASE_BASE_DIR}/job.yaml &&
    sed -i "s|#PROCESSING_BUCKET|${PROCESSING_BUCKET}|" ${MLP_USE_CASE_BASE_DIR}/job.yaml

echo_title "Getting cluster credentials"

print_and_execute "gcloud container fleet memberships get-credentials ${CLUSTER_NAME} --project ${PROJECT_ID}"
check_local_error_exit_on_error

echo_title "Creating job"

print_and_execute "kubectl apply -f ${MLP_USE_CASE_BASE_DIR}/job.yaml"
check_local_error_exit_on_error

echo_title "Waiting for job to complete"

print_and_execute "kubectl wait --namespace=ml-team --for=condition=complete --timeout=3600s job/job &
kubectl wait --namespace=ml-team --for=condition=failed --timeout=3600s job/job &
wait -n && \
pkill -f 'kubectl wait --namespace=ml-team'"
check_local_error_exit_on_error

echo_title "Checking processed images"

IMAGES_PROCESS=$(gsutil du gs://${PROCESSING_BUCKET}/flipkart_images | wc -l)
echo "Processed ${IMAGES_PROCESS} images."

print_and_execute "((IMAGES_PROCESS > 0))"
check_local_error_exit_on_error

echo_title "Removing IAM permissions"

gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member "serviceAccount:wi-ml-team-ray-head@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/storage.objectViewer

gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member "serviceAccount:wi-ml-team-ray-worker@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/storage.objectAdmin

echo_title "Deleting Artifact Registry repository"

gcloud artifacts repositories delete dataprocessing \
    --location=us \
    --project=${PROJECT_ID} \
    --quiet

echo_title "Deleting GCS buckets"

print_and_execute "gsutil -m -q rm -rf gs://${PROCESSING_BUCKET}/*"
print_and_execute "gcloud storage buckets delete gs://${PROCESSING_BUCKET} --project ${MLP_PROJECT_ID}"

print_and_execute "gsutil -m -q rm -rf gs://${PROJECT_ID}_cloudbuild/*"
print_and_execute "gcloud storage buckets delete gs://${PROJECT_ID}_cloudbuild --project ${MLP_PROJECT_ID}"

total_runtime "dataprocessing"
