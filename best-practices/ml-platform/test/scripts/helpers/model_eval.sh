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

start_runtime "model_eval"

echo_title "Preparing model evaluation"

export MLP_USE_CASE_BASE_DIR="${MLP_BASE_DIR}/examples/use-case/model-eval"

echo_title "Configure the cloudbuild.yaml"
git restore ${MLP_USE_CASE_BASE_DIR}/src/cloudbuild.yaml
sed -i -e "s|^serviceAccount:.*|serviceAccount: projects/${MLP_PROJECT_ID}/serviceAccounts/${MLP_BUILD_GSA}|" ${MLP_USE_CASE_BASE_DIR}/src/cloudbuild.yaml

echo_title "Building container image"
print_and_execute "cd ${MLP_USE_CASE_BASE_DIR}/src && \
gcloud beta builds submit --config cloudbuild.yaml \
--project ${MLP_PROJECT_ID} \
--substitutions _DESTINATION=${MLP_MODEL_EVALUATION_IMAGE}"
check_local_error_exit_on_error

echo_title "Getting cluster credentials"
print_and_execute "gcloud container fleet memberships get-credentials ${MLP_CLUSTER_NAME} --project ${MLP_PROJECT_ID}"
check_local_error_exit_on_error

echo_title "Configuring the deployment"
git restore ${MLP_USE_CASE_BASE_DIR}/manifests/deployment-${ACCELERATOR}.yaml
sed \
    -i -e "s|V_IMAGE_URL|${VLLM_IMAGE_URL}|" \
    -i -e "s|V_KSA|${MLP_MODEL_EVALUATION_KSA}|" \
    -i -e "s|V_BUCKET|${MLP_MODEL_BUCKET}|" \
    -i -e "s|V_MODEL_PATH|${MODEL}|" \
    ${MLP_USE_CASE_BASE_DIR}/manifests/deployment-${ACCELERATOR}.yaml

echo_title "Deleting exsting inference server deployment"
print_and_execute_no_check "kubectl --namespace ${MLP_KUBERNETES_NAMESPACE} delete -f ${MLP_USE_CASE_BASE_DIR}/manifests/deployment-${ACCELERATOR}.yaml"

echo_title "Creating the inference server deployment"
print_and_execute "kubectl --namespace ${MLP_KUBERNETES_NAMESPACE} apply -f ${MLP_USE_CASE_BASE_DIR}/manifests/deployment-${ACCELERATOR}.yaml"
check_local_error_exit_on_error

echo_title "Wait for the inference server deployment to be ready"
print_and_execute "kubectl --namespace ${MLP_KUBERNETES_NAMESPACE} wait --for=condition=ready --timeout=900s pod -l app=vllm-openai-${ACCELERATOR}"
check_local_error_exit_on_error

echo_title "Configuring the model evaluation job"
git restore ${MLP_USE_CASE_BASE_DIR}/manifests/job.yaml
sed \
    -i -e "s|V_DATA_BUCKET|${MLP_DATA_BUCKET}|" \
    -i -e "s|V_DATASET_OUTPUT_PATH|${DATASET_OUTPUT_PATH}|" \
    -i -e "s|V_ENDPOINT|${ENDPOINT}|" \
    -i -e "s|V_IMAGE_URL|${MLP_MODEL_EVALUATION_IMAGE}|" \
    -i -e "s|V_KSA|${MLP_MODEL_EVALUATION_KSA}|" \
    -i -e "s|V_MODEL_PATH|${MODEL_PATH}|" \
    -i -e "s|V_PREDICTIONS_FILE|${PREDICTIONS_FILE}|" \
    ${MLP_USE_CASE_BASE_DIR}/manifests/job.yaml

echo_title "Deleting exsting model evaluation job"
print_and_execute_no_check "kubectl --namespace ${MLP_KUBERNETES_NAMESPACE} delete -f ${MLP_USE_CASE_BASE_DIR}/manifests/job.yaml"

echo_title "Creating model evaluation job"
print_and_execute "kubectl --namespace ${MLP_KUBERNETES_NAMESPACE} apply -f ${MLP_USE_CASE_BASE_DIR}/manifests/job.yaml"
check_local_error_exit_on_error

echo_title "Waiting for job to complete"
print_and_execute "kubectl wait --namespace ${MLP_KUBERNETES_NAMESPACE} --for condition=complete --timeout 14400s job/model-eval &
kubectl wait --namespace ${MLP_KUBERNETES_NAMESPACE} --for condition=failed --timeout 14400s job/model-eval && exit 1 &
wait -n && \
pkill -f 'kubectl wait --namespace ${MLP_KUBERNETES_NAMESPACE}'"
check_local_error_exit_on_error

total_runtime "model_eval"
