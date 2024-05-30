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

check_local_error_exit_on_error

lock_unset "features_initialize_destroy"
lock_unset "terraform_destroy"

check_local_error_and_exit
