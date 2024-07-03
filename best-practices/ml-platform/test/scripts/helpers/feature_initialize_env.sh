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

echo_title "Applying feature initialize terraform configuration"

MLP_IAP_SUPPORT_EMAIL=${MLP_IAP_SUPPORT_EMAIL:-$(gcloud auth list --filter=status:ACTIVE --format="value(account)")}
sed -i '/^iap_support_email[[:blank:]]*=/{h;s/=.*/= "'"${MLP_IAP_SUPPORT_EMAIL}"'"/};${x;/^$/{s//iap_support_email = "'"${MLP_IAP_SUPPORT_EMAIL}"'"/;H};x}' ${MLP_BASE_DIR}/terraform/features/initialize/initialize.auto.tfvars

sed -i '/^  billing_account_id[[:blank:]]*=/{h;s/=.*/= "'"${MLP_BILLING_ACCOUNT_ID}"'"/};${x;/^$/{s//  billing_account_id = "'"${MLP_BILLING_ACCOUNT_ID}"'"/;H};x}' ${MLP_BASE_DIR}/terraform/features/initialize/initialize.auto.tfvars
sed -i '/^  folder_id[[:blank:]]*=/{h;s/=.*/= "'"${MLP_FOLDER_ID:-""}"'"/};${x;/^$/{s//  folder_id         = "'"${MLP_FOLDER_ID:-""}"'"/;H};x}' ${MLP_BASE_DIR}/terraform/features/initialize/initialize.auto.tfvars
sed -i '/^  org_id[[:blank:]]*=/{h;s/=.*/= "'"${MLP_ORG_ID:-""}"'"/};${x;/^$/{s//  org_id             = "'"${MLP_ORG_ID:-""}"'"/;H};x}' ${MLP_BASE_DIR}/terraform/features/initialize/initialize.auto.tfvars
