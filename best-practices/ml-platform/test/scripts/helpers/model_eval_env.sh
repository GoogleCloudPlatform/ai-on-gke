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

echo_title "Checking model-eval required configuration"

echo_title "Applying model-eval configuration"

export ACCELERATOR="l4"
export VLLM_IMAGE_URL="vllm/vllm-openai:v0.5.3.post1"
export MODEL="/model-data/model-gemma2/experiment"

export DATASET_OUTPUT_PATH="dataset/output"
export NDPOINT="http://vllm-openai-${ACCELERATOR}:8000/v1/chat/completions"
export MODEL_PATH="/model-data/model-gemma2/experiment"
export PREDICTIONS_FILE="predictions.txt"
