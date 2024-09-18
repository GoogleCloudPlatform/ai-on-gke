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

start_runtime "data_processing"

echo_title "Downloading the dataset and uploading to GCS"

print_and_execute "kaggle datasets download --force --unzip atharvjairath/flipkart-ecommerce-dataset && \
gcloud storage cp flipkart_com-ecommerce_sample.csv \
gs://${MLP_DATA_BUCKET}/flipkart_raw_dataset/flipkart_com-ecommerce_sample.csv && \
rm flipkart_com-ecommerce_sample.csv"
check_local_error_exit_on_error

export MLP_USE_CASE_BASE_DIR="${MLP_BASE_DIR}/examples/use-case/data-processing/ray"

echo_title "Configure the cloudbuild.yaml"
sed -i -e "s|^serviceAccount:.*|serviceAccount: projects/${MLP_PROJECT_ID}/serviceAccounts/${MLP_BUILD_GSA}|" ${MLP_USE_CASE_BASE_DIR}/src/cloudbuild.yaml

echo_title "Building container image"
print_and_execute "cd ${MLP_USE_CASE_BASE_DIR}/src && \
gcloud beta builds submit --config cloudbuild.yaml \
--project ${MLP_PROJECT_ID} \
--substitutions _DESTINATION=${MLP_DATA_PROCESSING_IMAGE}"
check_local_error_exit_on_error

echo_title "Getting cluster credentials"
print_and_execute "gcloud container fleet memberships get-credentials ${MLP_CLUSTER_NAME} --project ${MLP_PROJECT_ID}"
check_local_error_exit_on_error

echo_title "Configuring the job"

git restore ${MLP_USE_CASE_BASE_DIR}/manifests/job.yaml
sed \
    -i -e "s|V_DATA_BUCKET|${MLP_DATA_BUCKET}|" \
    -i -e "s|V_IMAGE_URL|${MLP_DATA_PROCESSING_IMAGE}|" \
    -i -e "s|V_KSA|${MLP_DATA_PROCESSING_KSA}|" \
    ${MLP_USE_CASE_BASE_DIR}/manifests/job.yaml

echo_title "Deleting exsting job"
print_and_execute_no_check "kubectl --namespace=${MLP_KUBERNETES_NAMESPACE} delete -f ${MLP_USE_CASE_BASE_DIR}/manifests/job.yaml"

echo_title "Creating job"
print_and_execute "kubectl --namespace=${MLP_KUBERNETES_NAMESPACE} apply -f ${MLP_USE_CASE_BASE_DIR}/manifests/job.yaml"
check_local_error_exit_on_error

echo_title "Waiting for job to complete"
print_and_execute "kubectl wait --namespace=${MLP_KUBERNETES_NAMESPACE} --for=condition=complete --timeout=3600s job/data-processing &
kubectl wait --namespace=${MLP_KUBERNETES_NAMESPACE} --for=condition=failed --timeout=3600s job/data-processing && exit 1 &
wait -n && \
pkill -f 'kubectl wait --namespace=${MLP_KUBERNETES_NAMESPACE}'"
check_local_error_exit_on_error

echo_title "Checking processed images"
IMAGES_PROCESS=$(gsutil du gs://${MLP_DATA_BUCKET}/flipkart_images | wc -l)
echo_bold "Processed ${IMAGES_PROCESS} images."

print_and_execute "((IMAGES_PROCESS > 0))"
check_local_error_exit_on_error

total_runtime "data_processing"
