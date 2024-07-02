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

echo_title "Checking new_gh required configuration"

if [ ! -f ${HOME}/secrets/mlp-github-token ]; then
    echo_error "Git token missing at '${HOME}/secrets/mlp-github-token'!"
    exit 3
fi

if [ -z "${MLP_GIT_NAMESPACE}" ]; then
    echo_error "MLP_GIT_NAMESPACE is not set!"
    exit 4
fi

if [ -z "${MLP_GIT_USER_NAME}" ]; then
    echo_error "MLP_GIT_USER_NAME is not set!"
    exit 5
fi

if [ -z "${MLP_GIT_USER_EMAIL}" ]; then
    echo_error "MLP_GIT_USER_EMAIL is not set!"
    exit 6
fi

if [ -z "${MLP_FOLDER_ID}" ] && [ -z "${MLP_ORG_ID}" ]; then
    echo_error "MLP_FOLDER_ID or MLP_ORG_ID is not set, at least one needs to be set!"
    exit 6
fi

source ${SCRIPTS_DIR}/helpers/gh_env.sh
