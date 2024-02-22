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
LOCUS_OPTS="-f /locust-tasks/tasks.py --host=$TARGET_HOST"
LOCUST_MODE=${LOCUST_MODE:-standalone}

if [[ "$LOCUST_MODE" = "master" ]]; then
    LOCUS_OPTS="$LOCUS_OPTS --master --stop-timeout 300"
elif [[ "$LOCUST_MODE" = "worker" ]]; then
    FILTER_PROMPTS="python /locust-tasks/load_data.py"
    FILTER_PROMPTS_OPTS="--gcs_path=$GCS_PATH --tokenizer=$TOKENIZER --max_prompt_len=$MAX_PROMPT_LEN --max_num_prompts=$MAX_NUM_PROMPTS"
    echo "$FILTER_PROMPTS $FILTER_PROMPTS_OPTS"
    $FILTER_PROMPTS $FILTER_PROMPTS_OPTS

    LOCUS_OPTS="$LOCUS_OPTS --worker --master-host=$LOCUST_MASTER"
fi

echo "$LOCUST $LOCUS_OPTS"

$LOCUST $LOCUS_OPTS
