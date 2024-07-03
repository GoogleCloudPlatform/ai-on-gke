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

echo_title "Checking BYOP required configuration"

if [ -z "${MLP_PROJECT_ID}" ]; then
    echo "MLP_PROJECT_ID is not set!"
    exit 7
fi

export MLP_ENVIRONMENT_NAME=${MLP_ENVIRONMENT_NAME:-$(grep environment_name ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars | awk -F"=" '{print $2}' | xargs)}

export MLP_STATE_BUCKET="${MLP_PROJECT_ID}-${MLP_ENVIRONMENT_NAME}-terraform"

export TF_DATA_DIR=".terraform-${MLP_PROJECT_ID}-${MLP_ENVIRONMENT_NAME}"

echo_title "Applying terraform configuration"

sed -i "s/^\([[:blank:]]*bucket[[:blank:]]*=\).*$/\1 \"${MLP_STATE_BUCKET}\"/" ${MLP_TYPE_BASE_DIR}/backend.tf
sed -i "s/^\([[:blank:]]*environment_name[[:blank:]]*=\).*$/\1 \"${MLP_ENVIRONMENT_NAME}\"/" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars
sed -i "s/^\([[:blank:]]*environment_project_id[[:blank:]]*=\).*$/\1 \"${MLP_PROJECT_ID}\"/" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars
