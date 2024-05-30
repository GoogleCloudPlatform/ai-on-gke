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

check_local_error_and_exit

lock_unset "features_initialize_apply"
lock_unset "terraform_apply"

check_local_error_and_exit
