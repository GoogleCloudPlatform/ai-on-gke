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

# terraform destroy
###############################################################################

if lock_is_set "terraform_destroy"; then
    echo_bold "Terraform destory previously completed successfully"
else
    export TF_VAR_github_token=$(tr --delete '\n' <${HOME}/secrets/mlp-github-token)
    source ${SCRIPTS_DIR}/helpers/terraform_destroy.sh
    lock_set "terraform_destroy"
fi

# feature initialize destroy
###############################################################################

if lock_is_set "features_initialize_destroy"; then
    echo_bold "Feature initialize destroy previously completed successfully"
else
    source ${SCRIPTS_DIR}/helpers/feature_initialize_destroy.sh

    lock_set "features_initialize_destroy"
fi

# cleanup
###############################################################################
echo_title "Cleaning up the environment"

source ${SCRIPTS_DIR}/helpers/new_gh_playground_cleanup.sh

check_local_error_exit_on_error

lock_unset "features_initialize_destroy"
lock_unset "terraform_destroy"

check_local_error_and_exit
