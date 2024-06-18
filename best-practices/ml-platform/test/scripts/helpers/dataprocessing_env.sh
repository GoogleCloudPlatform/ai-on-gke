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

echo_title "Checking dataprocessing required configuration"
source ${SCRIPTS_DIR}/helpers/kaggle.sh "datasets files atharvjairath/flipkart-ecommerce-dataset"
check_local_error_exit_on_error

if [ -z "${MLP_PROJECT_ID}" ]; then
    echo "MLP_PROJECT_ID is not set!"
    exit 7
fi

echo_title "Applying dataprocessing configuration"
export CLUSTER_NAME="mlp-${MLP_ENVIRONMENT_NAME}"
export PROJECT_ID="${MLP_PROJECT_ID}"
export PROCESSING_BUCKET="${PROJECT_ID}-processing"
export DOCKER_IMAGE_URL=us-docker.pkg.dev/${PROJECT_ID}/dataprocessing/dp:v0.0.1
