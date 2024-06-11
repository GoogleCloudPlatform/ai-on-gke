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

echo_title "Checking byop_gh required configuration"

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

if [ -z "${MLP_PROJECT_ID}" ]; then
    echo "MLP_PROJECT_ID is not set!"
    exit 7
fi

export MLP_STATE_BUCKET="${MLP_PROJECT_ID}-terraform"

source ${SCRIPTS_DIR}/helpers/gh_env.sh
