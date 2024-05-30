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

SCRIPT_PATH="$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)"

source ${SCRIPT_PATH}/helpers/include.sh

echo_title "Preparing the environment"
export MLP_TYPE_BASE_DIR="${MLP_BASE_DIR}/examples/platform/playground"

echo_title "Checking required configuration"
source ${SCRIPT_PATH}/helpers/kaggle.sh "datasets files atharvjairath/flipkart-ecommerce-dataset"
check_local_error_exit_on_error

if [ ! -f ${HOME}/secrets/mlp-github-token ]; then
    echo "Git token missing at '${HOME}/secrets/mlp-github-token'!"
    exit 3
fi

if [ -z "${MLP_GITHUB_ORG}" ]; then
    echo "MLP_GITHUB_ORG is not set!"
    exit 4
fi

if [ -z "${MLP_GITHUB_USER}" ]; then
    echo "MLP_GITHUB_USER is not set!"
    exit 5
fi

if [ -z "${MLP_GITHUB_EMAIL}" ]; then
    echo "MLP_GITHUB_EMAIL is not set!"
    exit 6
fi

if [ -z "${MLP_FOLDER_ID}" ] && [ -z "${MLP_ORG_ID}" ]; then
    echo "MLP_FOLDER_ID or MLP_ORG_ID is not set, at least one needs to be set!"
    exit 6
fi

# feature initialize apply
###############################################################################
if lock_is_set "features_initialize_apply"; then
    echo_bold "Feature initialize apply previously completed successfully"
else
    echo_title "Applying feature initialize terraform configuration"

    MLP_IAP_SUPPORT_EMAIL=${MLP_IAP_SUPPORT_EMAIL:-$(gcloud auth list --filter=status:ACTIVE --format="value(account)")}
    sed -i '/^iap_support_email[[:blank:]]*=/{h;s/=.*/= "'"${MLP_IAP_SUPPORT_EMAIL}"'"/};${x;/^$/{s//iap_support_email = "'"${MLP_IAP_SUPPORT_EMAIL}"'"/;H};x}' ${MLP_BASE_DIR}/terraform/features/initialize/initialize.auto.tfvars

    sed -i '/^  billing_account_id[[:blank:]]*=/{h;s/=.*/= "'"${MLP_BILLING_ACCOUNT_ID}"'"/};${x;/^$/{s//  billing_account_id = "'"${MLP_BILLING_ACCOUNT_ID}"'"/;H};x}' ${MLP_BASE_DIR}/terraform/features/initialize/initialize.auto.tfvars
    sed -i '/^  folder_id[[:blank:]]*=/{h;s/=.*/= "'"${MLP_FOLDER_ID:-""}"'"/};${x;/^$/{s//  folder_id         = "'"${MLP_FOLDER_ID:-""}"'"/;H};x}' ${MLP_BASE_DIR}/terraform/features/initialize/initialize.auto.tfvars
    sed -i '/^  org_id[[:blank:]]*=/{h;s/=.*/= "'"${MLP_ORG_ID:-""}"'"/};${x;/^$/{s//  org_id             = "'"${MLP_ORG_ID:-""}"'"/;H};x}' ${MLP_BASE_DIR}/terraform/features/initialize/initialize.auto.tfvars

    source ${SCRIPT_PATH}/helpers/feature_initialize_apply.sh

    lock_set "features_initialize_apply"
fi

export MLP_PROJECT_ID=$(grep environment_project_id ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars | awk -F"=" '{print $2}' | xargs)

# terraform apply
###############################################################################
if lock_is_set "terraform_apply"; then
    echo_bold "Terraform apply previously completed successfully"
else
    echo_title "Applying terraform configuration"
    sed -i "s/YOUR_GITHUB_EMAIL/${MLP_GITHUB_EMAIL}/g" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars
    sed -i "s/YOUR_GITHUB_ORG/${MLP_GITHUB_ORG}/g" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars
    sed -i "s/YOUR_GITHUB_USER/${MLP_GITHUB_USER}/g" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars

    echo_title "Checking MLP_IAP_DOMAIN"
    MLP_IAP_DOMAIN=${IAP_DOMAIN:-$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | awk -F@ '{print $2}')}
    echo "MLP_IAP_DOMAIN=${MLP_IAP_DOMAIN}"
    sed -i '/^iap_domain[[:blank:]]*=/{h;s/=.*/= "'"${MLP_IAP_DOMAIN}"'"/};${x;/^$/{s//iap_domain             = "'"${MLP_IAP_DOMAIN}"'"/;H};x}' ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars

    echo_title "Checking ray-dashboard endpoint"
    gcloud endpoints services undelete ray-dashboard.ml-team.mlp.endpoints.${MLP_PROJECT_ID}.cloud.goog --quiet 2>/dev/null

    export TF_VAR_github_token=$(tr --delete '\n' <${HOME}/secrets/mlp-github-token)

    source ${SCRIPT_PATH}/helpers/terraform_apply.sh

    lock_set "terraform_apply"
fi

# dataprocessing
###############################################################################
if lock_is_set "dataprocessing"; then
    echo_bold "Dataprocessing previously completed successfully"
else
    ENVIRONMENT_NAME=$(grep environment_name ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars | awk -F"=" '{print $2}' | xargs)
    export CLUSTER_NAME="gke-ml-${ENVIRONMENT_NAME}"
    export PROJECT_ID="${MLP_PROJECT_ID}"
    export PROCESSING_BUCKET="${PROJECT_ID}-processing"
    export DOCKER_IMAGE_URL=us-docker.pkg.dev/${PROJECT_ID}/dataprocessing/dp:v0.0.1

    source ${SCRIPT_PATH}/helpers/dataprocessing.sh

    lock_set "dataprocessing"
fi

# terraform destroy
###############################################################################

if lock_is_set "terraform_destroy"; then
    echo_bold "Terraform destory previously completed successfully"
else
    export TF_VAR_github_token=$(tr --delete '\n' <${HOME}/secrets/mlp-github-token)
    source ${SCRIPT_PATH}/helpers/terraform_destroy.sh
    lock_set "terraform_destroy"
fi

# feature initialize destroy
###############################################################################

if lock_is_set "features_initialize_destroy"; then
    echo_bold "Feature initialize destroy previously completed successfully"
else
    source ${SCRIPT_PATH}/helpers/feature_initialize_destroy.sh

    lock_set "features_initialize_destroy"
fi

# cleanup
###############################################################################
echo_title "Cleaning up local repository"

cd ${MLP_BASE_DIR} &&
    git restore \
        examples/platform/playground/backend.tf \
        examples/platform/playground/mlp.auto.tfvars \
        examples/use-case/ray/dataprocessing/job.yaml \
        terraform/features/initialize/backend.tf \
        terraform/features/initialize/backend.tf.bucket \
        terraform/features/initialize/initialize.auto.tfvars

cd ${MLP_BASE_DIR} &&
    rm -rf \
        examples/platform/playground/.terraform \
        examples/platform/playground/.terraform.lock.hcl \
        terraform/features/initialize/.terraform \
        terraform/features/initialize/.terraform.lock.hcl \
        terraform/features/initialize/backend.tf.local \
        terraform/features/initialize/state

total_runtime "script"

check_local_error_exit_on_error

lock_unset "dataprocessing"
lock_unset "features_initialize_apply"
lock_unset "features_initialize_destroy"
lock_unset "terraform_apply"
lock_unset "terraform_destroy"

check_local_error_and_exit
