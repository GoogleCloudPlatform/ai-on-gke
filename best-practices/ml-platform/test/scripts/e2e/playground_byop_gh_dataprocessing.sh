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
source ${SCRIPTS_DIR}/helpers/byop_env.sh
source ${SCRIPTS_DIR}/helpers/gh_env.sh
source ${SCRIPTS_DIR}/helpers/dataprocessing_env.sh

# terraform apply
###############################################################################
if lock_is_set "terraform_apply"; then
    echo_bold "Terraform apply previously completed successfully"
else
    source ${SCRIPTS_DIR}/helpers/${MLP_TYPE}_env.sh
    export TF_VAR_git_token=$(tr --delete '\n' <${HOME}/secrets/mlp-github-token)
    source ${SCRIPTS_DIR}/helpers/terraform_apply.sh
    lock_set "terraform_apply"
fi

# dataprocessing
###############################################################################
if lock_is_set "dataprocessing"; then
    echo_bold "Dataprocessing previously completed successfully"
else
    source ${SCRIPTS_DIR}/helpers/dataprocessing.sh
    lock_set "dataprocessing"
fi

# terraform destroy
###############################################################################
if lock_is_set "terraform_destroy"; then
    echo_bold "Terraform destory previously completed successfully"
else
    export TF_VAR_git_token=$(tr --delete '\n' <${HOME}/secrets/mlp-github-token)
    source ${SCRIPTS_DIR}/helpers/terraform_destroy.sh
    lock_set "terraform_destroy"
fi

# cleanup
###############################################################################
echo_title "Cleaning up the environment"

source ${SCRIPTS_DIR}/helpers/dataprocessing_cleanup.sh
source ${SCRIPTS_DIR}/helpers/byop_playground_cleanup.sh

total_runtime "script"

check_local_error_exit_on_error

lock_unset "dataprocessing"
lock_unset "terraform_apply"
lock_unset "terraform_destroy"

check_local_error_and_exit
