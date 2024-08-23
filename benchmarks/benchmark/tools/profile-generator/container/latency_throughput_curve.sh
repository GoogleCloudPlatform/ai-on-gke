#!/bin/bash

# Copyright 2024 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -o xtrace

export IP=$IP

huggingface-cli login --token "$HF_TOKEN" --add-to-git-credential

for request_rate in $(echo $REQUEST_RATES | tr ',' ' '); do
  # TODO: Check if profile already exists, if so then skip
  timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
  output_file="latency-profile-${timestamp}.txt"
  python3 benchmark_serving.py   --host="$IP"   --port="$PORT"   --dataset=ShareGPT_V3_unfiltered_cleaned_split.json   --tokenizer="$TOKENIZER" --request-rate=$request_rate --backend="$BACKEND" --num-prompts=$((request_rate * 30)) --max-input-length=$INPUT_LENGTH --max-output-length=$OUTPUT_LENGTH > $output_file
done