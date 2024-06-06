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
SCRIPTS_DIR=$(realpath ${SCRIPT_PATH}/..)

export MLP_TYPE="playground"
source ${SCRIPTS_DIR}/helpers/include.sh

echo_title "Preparing the environment"
source ${SCRIPTS_DIR}/helpers/new_gh_env.sh

# feature initialize apply
###############################################################################
if lock_is_set "features_initialize_apply"; then
    echo_bold "Feature initialize apply previously completed successfully"
else
    source ${SCRIPTS_DIR}/helpers/feature_initialize_env.sh
    source ${SCRIPTS_DIR}/helpers/feature_initialize_apply.sh
    lock_set "features_initialize_apply"
fi

export MLP_PROJECT_ID=$(grep environment_project_id ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars | awk -F"=" '{print $2}' | xargs)

# terraform apply
###############################################################################
if lock_is_set "terraform_apply"; then
    echo_bold "Terraform apply previously completed successfully"
else
    source ${SCRIPTS_DIR}/helpers/${MLP_TYPE}_env.sh

    export TF_VAR_github_token=$(tr --delete '\n' <${HOME}/secrets/mlp-github-token)
    source ${SCRIPTS_DIR}/helpers/terraform_apply.sh
    lock_set "terraform_apply"
fi

check_local_error_and_exit

lock_unset "features_initialize_apply"
lock_unset "terraform_apply"

check_local_error_and_exit
