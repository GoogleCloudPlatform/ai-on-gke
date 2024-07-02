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

echo_title "Deleting Terraform GCS bucket"
gsutil -m rm -rf gs://${MLP_STATE_BUCKET}/*
gcloud storage buckets delete gs://${MLP_STATE_BUCKET} --project ${MLP_PROJECT_ID}

echo_title "Cleaning up local repository changes"

cd ${MLP_BASE_DIR} &&
    git restore \
        examples/platform/playground/backend.tf \
        examples/platform/playground/mlp.auto.tfvars

cd ${MLP_BASE_DIR} &&
    rm -rf \
        examples/platform/playground/${TF_DATA_DIR} \
        examples/platform/playground/.terraform.lock.hcl
