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

start_runtime "features_initialize_destroy"

echo_title "Destroying the project"

export TERRAFORM_BUCKET_NAME=$(grep bucket ${MLP_BASE_DIR}/terraform/features/initialize/backend.tf | awk -F"=" '{print $2}' | xargs)
print_and_execute "cd ${MLP_BASE_DIR}/terraform/features/initialize && \
cp backend.tf.local backend.tf && \
terraform init -force-copy -lock=false -migrate-state && \
gsutil -m rm -rf gs://${TERRAFORM_BUCKET_NAME}/* && \
terraform init && \
terraform destroy -auto-approve  && \
rm -rf .terraform .terraform.lock.hcl"

total_runtime "features_initialize_destroy"

check_local_error_exit_on_error
