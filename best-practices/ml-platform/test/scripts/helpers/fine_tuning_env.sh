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

echo_title "Checking fine-tuning required configuration"

HF_TOKEN_FILE=${HF_TOKEN_FILE:-${HOME}/secrets/mlp-hugging-face-token}

if [ ! -f ${HF_TOKEN_FILE} ]; then
    echo "Hugging Face token missing at '${HF_TOKEN_FILE}'!"
    exit 3
fi

echo_title "Applying fine-tuning configuration"

random_suffix=$(echo $RANDOM | md5sum | head -c 8)

export ACCELERATOR="l4"
export DATA_BUCKET_DATASET_PATH="dataset/output/training"
export EXPERIMENT="finetune-${random_suffix}"
export HF_BASE_MODEL_NAME="google/gemma-2-9b-it"
export MLFLOW_ENABLE="true"
export MLFLOW_ENABLE_SYSTEM_METRICS_LOGGING="true"
export MLFLOW_TRACKING_URI="http://mlflow-tracking-svc:5000"
export MODEL_PATH="/model-data/model-gemma2/${EXPERIMENT}"
