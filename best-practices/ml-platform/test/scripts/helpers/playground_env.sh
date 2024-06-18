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

echo_title "Applying terraform configuration"

sed -i "s/^\([[:blank:]]*bucket[[:blank:]]*=\).*$/\1 \"${MLP_STATE_BUCKET}\"/" ${MLP_TYPE_BASE_DIR}/backend.tf
sed -i "s/^\([[:blank:]]*environment_name[[:blank:]]*=\).*$/\1 \"${MLP_ENVIRONMENT_NAME}\"/" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars
sed -i "s/^\([[:blank:]]*environment_project_id[[:blank:]]*=\).*$/\1 \"${MLP_PROJECT_ID}\"/" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars

echo_title "Creating GCS bucket"
gcloud storage buckets create gs://${MLP_STATE_BUCKET} --project ${MLP_PROJECT_ID}

echo_title "Checking MLP_IAP_DOMAIN"
MLP_IAP_DOMAIN=${MLP_IAP_DOMAIN:-$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | awk -F@ '{print $2}')}
echo "MLP_IAP_DOMAIN=${MLP_IAP_DOMAIN}"
sed -i '/^iap_domain[[:blank:]]*=/{h;s/=.*/= "'"${MLP_IAP_DOMAIN}"'"/};${x;/^$/{s//iap_domain             = "'"${MLP_IAP_DOMAIN}"'"/;H};x}' ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars

echo_title "Checking ray-dashboard endpoint"
gcloud endpoints services undelete ray-dashboard.ml-team.mlp.endpoints.${MLP_PROJECT_ID}.cloud.goog --quiet 2>/dev/null
