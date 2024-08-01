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

echo_title "Checking base platform required configuration"

if [ -z "${MLP_PLATFORM_ENG_PROJECT_ID}" ]; then
    echo "MLP_PLATFORM_ENG_PROJECT_ID is not set!"
    exit 7
fi

export MLP_STATE_BUCKET="${MLP_PLATFORM_ENG_PROJECT_ID}-mlp-terraform"

echo_title "Applying terraform configuration"

sed -i "s/^\([[:blank:]]*bucket[[:blank:]]*=\).*$/\1 \"${MLP_STATE_BUCKET}\"/" ${MLP_TYPE_BASE_DIR}/backend.tf
sed -i "s/^\([[:blank:]]*platform_eng_project_id[[:blank:]]*=\).*$/\1 \"${MLP_PLATFORM_ENG_PROJECT_ID}\"/" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars

echo_title "Creating GCS bucket"
gcloud storage buckets create gs://${MLP_STATE_BUCKET} --project ${MLP_PROJECT_ID}
