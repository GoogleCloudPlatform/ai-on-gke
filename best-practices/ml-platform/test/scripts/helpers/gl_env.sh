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

echo_title "Checking GitLab required configuration"

export GIT_TOKEN_FILE=${GIT_TOKEN_FILE:-${HOME}/secrets/mlp-gitlab-token}

if [ ! -f ${GIT_TOKEN_FILE} ]; then
    echo "Git token missing at '${GIT_TOKEN_FILE}'!"
    exit 3
fi

if [ -z "${MLP_GIT_NAMESPACE}" ]; then
    echo "MLP_GIT_NAMESPACE is not set!"
    exit 4
fi

if [ -z "${MLP_GIT_USER_NAME}" ]; then
    echo "MLP_GIT_USER_NAME is not set!"
    exit 5
fi

if [ -z "${MLP_GIT_USER_EMAIL}" ]; then
    echo "MLP_GIT_USER_EMAIL is not set!"
    exit 6
fi

echo_title "Applying Git configuration"
sed -i "s/YOUR_GIT_NAMESPACE/${MLP_GIT_NAMESPACE}/g" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars
sed -i "s/YOUR_GIT_USER_EMAIL/${MLP_GIT_USER_EMAIL}/g" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars
sed -i "s/YOUR_GIT_USER_NAME/${MLP_GIT_USER_NAME}/g" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars
