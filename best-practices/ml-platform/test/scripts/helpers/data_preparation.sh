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

start_runtime "data_preparation"

echo_title "Preparing data-preparation"

export MLP_USE_CASE_BASE_DIR="${MLP_BASE_DIR}/examples/use-case/data-preparation/gemma-it"

echo_title "Configure the cloudbuild.yaml"
git restore ${MLP_USE_CASE_BASE_DIR}/src/cloudbuild.yaml
sed -i -e "s|^serviceAccount:.*|serviceAccount: projects/${MLP_PROJECT_ID}/serviceAccounts/${MLP_BUILD_GSA}|" ${MLP_USE_CASE_BASE_DIR}/src/cloudbuild.yaml

echo_title "Building container image"
print_and_execute "cd ${MLP_USE_CASE_BASE_DIR}/src && \
gcloud beta builds submit --config cloudbuild.yaml \
--project ${MLP_PROJECT_ID} \
--substitutions _DESTINATION=${MLP_DATA_PREPARATION_IMAGE}"
check_local_error_exit_on_error

echo_title "Getting cluster credentials"
print_and_execute "gcloud container fleet memberships get-credentials ${MLP_CLUSTER_NAME} --project ${MLP_PROJECT_ID}"
check_local_error_exit_on_error

echo_title "Configuring the job"
git restore ${MLP_USE_CASE_BASE_DIR}/manifests/job.yaml
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
    ${MLP_USE_CASE_BASE_DIR}/manifests/job.yaml

echo_title "Deleting exsting job"
print_and_execute_no_check "kubectl --namespace ${MLP_KUBERNETES_NAMESPACE} delete -f ${MLP_USE_CASE_BASE_DIR}/manifests/job.yaml"

echo_title "Creating job"
print_and_execute "kubectl --namespace ${MLP_KUBERNETES_NAMESPACE} apply -f ${MLP_USE_CASE_BASE_DIR}/manifests/job.yaml"
check_local_error_exit_on_error

echo_title "Waiting for job to complete"
print_and_execute "kubectl wait --namespace=${MLP_KUBERNETES_NAMESPACE} --for=condition=complete --timeout=14400s job/data-prep &
kubectl wait --namespace=${MLP_KUBERNETES_NAMESPACE} --for=condition=failed --timeout=14400s job/data-prep && exit 1 &
wait -n && \
pkill -f 'kubectl wait --namespace=${MLP_KUBERNETES_NAMESPACE}'"
check_local_error_exit_on_error

echo_title "Listing the GCS bucket"
gcloud storage ls gs://${MLP_DATA_BUCKET}/${DATASET_OUTPUT_PATH}

total_runtime "data_preparation"
