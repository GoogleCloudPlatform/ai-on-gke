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

echo_title "Cleaning up local repository changes"

print_and_execute_no_check "cd ${MLP_BASE_DIR} &&
git restore \
examples/platform/playground/backend.tf \
examples/platform/playground/mlp.auto.tfvars \
terraform/features/initialize/backend.tf \
terraform/features/initialize/backend.tf.bucket \
terraform/features/initialize/initialize.auto.tfvars"

print_and_execute_no_check "cd ${MLP_BASE_DIR} &&
rm -rf \
examples/platform/playground/.terraform \
examples/platform/playground/.terraform.lock.hcl \
terraform/features/initialize/.terraform \
terraform/features/initialize/.terraform.lock.hcl \
terraform/features/initialize/backend.tf.local \
terraform/features/initialize/stateck.hcl"
