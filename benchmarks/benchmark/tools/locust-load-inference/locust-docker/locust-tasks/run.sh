#!/bin/bash

# Copyright 2022 Google Inc. All rights reserved.
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

LOCUST="/usr/local/bin/locust"
LOCUST_OPTS="-f /locust-tasks/tasks.py "
LOCUST_MODE=${LOCUST_MODE:-standalone}

if [[ "$REQUEST_TYPE" = "grpc" ]]; then 
    LOCUST_OPTS="$LOCUST_OPTS GrpcBenchmarkUser --host=$TARGET_HOST"
else
    LOCUST_OPTS="$LOCUST_OPTS BenchmarkUser --host='http://$TARGET_HOST"
fi

if [[ "$LOCUST_MODE" = "master" ]]; then
    # Locust stop-timeout default is 0s. Only used in distributed mode.
    # Master will wait $stop-timout amount of time for the User to complete it's task.
    # For inferencing workloads with large payload having no wait time is unreasonable.
    # This timeout is set to large amount to avoid user tasks being killed too early.
    # TODO: turn timeout into a variable.
    LOCUST_OPTS="$LOCUST_OPTS --master "
    if [[ "$STOP_TIMEOUT" != 0 ]]; then
        LOCUST_OPTS="$LOCUST_OPTS --stop-timeout $STOP_TIMEOUT"
    fi
elif [[ "$LOCUST_MODE" = "worker" ]]; then
    huggingface-cli login --token $HUGGINGFACE_TOKEN
    FILTER_PROMPTS="python /locust-tasks/load_data.py"
    FILTER_PROMPTS_OPTS="--gcs_path=$GCS_PATH --tokenizer=$TOKENIZER --max_prompt_len=$MAX_PROMPT_LEN --max_num_prompts=$MAX_NUM_PROMPTS"
    echo "$FILTER_PROMPTS $FILTER_PROMPTS_OPTS"
    $FILTER_PROMPTS $FILTER_PROMPTS_OPTS

    LOCUST_OPTS="$LOCUST_OPTS --worker --master-host=$LOCUST_MASTER"
fi

echo "$LOCUST $LOCUST_OPTS"

$LOCUST $LOCUST_OPTS
