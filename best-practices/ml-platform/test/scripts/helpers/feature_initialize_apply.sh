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

start_runtime "features_initialize_apply"

echo_title "Initializing a new project"

print_and_execute "cd ${MLP_BASE_DIR}/terraform/features/initialize && \
terraform init && \
terraform plan -input=false -out=tfplan && \
terraform apply -input=false tfplan && \
rm tfplan && \
terraform init -force-copy -migrate-state && \
rm -rf state"

total_runtime "features_initialize_apply"

check_local_error_exit_on_error
