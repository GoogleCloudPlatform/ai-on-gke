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

start_runtime "fine_tuning"

echo_title "Preparing fine-tuning"

export MLP_USE_CASE_BASE_DIR="${MLP_BASE_DIR}/examples/use-case/fine-tuning/pytorch"

echo_title "Configure the cloudbuild.yaml"
git restore ${MLP_USE_CASE_BASE_DIR}/src/cloudbuild.yaml
sed -i -e "s|^serviceAccount:.*|serviceAccount: projects/${MLP_PROJECT_ID}/serviceAccounts/${MLP_BUILD_GSA}|" ${MLP_USE_CASE_BASE_DIR}/src/cloudbuild.yaml

echo_title "Building container image"
print_and_execute "cd ${MLP_USE_CASE_BASE_DIR}/src && \
gcloud beta builds submit --config cloudbuild.yaml \
--project ${MLP_PROJECT_ID} \
--substitutions _DESTINATION=${MLP_FINE_TUNING_IMAGE}"
check_local_error_exit_on_error

echo_title "Getting cluster credentials"
print_and_execute "gcloud container fleet memberships get-credentials ${MLP_CLUSTER_NAME} --project ${MLP_PROJECT_ID}"
check_local_error_exit_on_error

echo_title "Creating Hugging Face token secret in cluster"
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token="$(tr --delete '\n' <${HF_TOKEN_FILE})" \
    --dry-run=client -o yaml | kubectl apply -n ${MLP_KUBERNETES_NAMESPACE} -f -

echo_title "Configuring the job"
git restore ${MLP_USE_CASE_BASE_DIR}/manifests/fine-tune-${ACCELERATOR}-dws.yaml
sed \
    -i -e "s|V_DATA_BUCKET|${MLP_DATA_BUCKET}|" \
    -i -e "s|V_EXPERIMENT|${EXPERIMENT}|" \
    -i -e "s|V_MODEL_NAME|${HF_BASE_MODEL_NAME}|" \
    -i -e "s|V_IMAGE_URL|${MLP_FINE_TUNING_IMAGE}|" \
    -i -e "s|V_KSA|${MLP_FINE_TUNING_KSA}|" \
    -i -e "s|V_MLFLOW_ENABLE_SYSTEM_METRICS_LOGGING|${MLFLOW_ENABLE_SYSTEM_METRICS_LOGGING}|" \
    -i -e "s|V_MLFLOW_ENABLE|${MLFLOW_ENABLE}|" \
    -i -e "s|V_MLFLOW_TRACKING_URI|${MLFLOW_TRACKING_URI}|" \
    -i -e "s|V_MODEL_BUCKET|${MLP_MODEL_BUCKET}|" \
    -i -e "s|V_MODEL_PATH|${MODEL_PATH}|" \
    -i -e "s|V_TRAINING_DATASET_PATH|${DATA_BUCKET_DATASET_PATH}|" \
    ${MLP_USE_CASE_BASE_DIR}/manifests/fine-tune-${ACCELERATOR}-dws.yaml

echo_title "Deleting exsting job"
print_and_execute_no_check "kubectl --namespace ${MLP_KUBERNETES_NAMESPACE} delete -f ${MLP_USE_CASE_BASE_DIR}/manifests/fine-tune-${ACCELERATOR}-dws.yaml"
print_and_execute_no_check "kubectl --namespace ${MLP_KUBERNETES_NAMESPACE} delete -f ${MLP_USE_CASE_BASE_DIR}/manifests/provisioning-request-${ACCELERATOR}.yaml"

echo_title "Creating job"
print_and_execute "kubectl --namespace ${MLP_KUBERNETES_NAMESPACE} apply -f ${MLP_USE_CASE_BASE_DIR}/manifests/provisioning-request-${ACCELERATOR}.yaml"
print_and_execute "kubectl --namespace ${MLP_KUBERNETES_NAMESPACE} apply -f ${MLP_USE_CASE_BASE_DIR}/manifests/fine-tune-${ACCELERATOR}-dws.yaml"
check_local_error_exit_on_error

echo_title "Wait for the provisioning request"
print_and_execute "kubectl wait --namespace=ml-team --for=condition=provisioned --timeout=14400s provisioningrequest/${ACCELERATOR}-job"
check_local_error_exit_on_error

echo_title "Waiting for job to complete"
print_and_execute "kubectl wait --namespace=${MLP_KUBERNETES_NAMESPACE} --for=condition=complete --timeout=14400s job/finetune-gemma-${ACCELERATOR} &
kubectl wait --namespace=${MLP_KUBERNETES_NAMESPACE} --for=condition=failed --timeout=14400s job/finetune-gemma-${ACCELERATOR} && exit 1 &
wait -n && \
pkill -f 'kubectl wait --namespace=${MLP_KUBERNETES_NAMESPACE}'"
check_local_error_exit_on_error

echo_title "Listing the GCS bucket"
gcloud storage ls gs://${MLP_MODEL_BUCKET}/${MODEL_PATH}

total_runtime "fine_tuning"
