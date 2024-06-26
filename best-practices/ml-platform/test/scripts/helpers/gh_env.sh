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

echo_title "Applying GitHub configuration"
sed -i "s/YOUR_GITHUB_EMAIL/${MLP_GITHUB_EMAIL}/g" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars
sed -i "s/YOUR_GITHUB_ORG/${MLP_GITHUB_ORG}/g" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars
sed -i "s/YOUR_GITHUB_USER/${MLP_GITHUB_USER}/g" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars
