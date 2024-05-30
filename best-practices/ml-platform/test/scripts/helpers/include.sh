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

source ${SCRIPT_PATH}/helpers/display.sh
source ${SCRIPT_PATH}/helpers/functions.sh

start_runtime "script"

# Create a logs file and send stdout and stderr to console and log file
log_directory=$(realpath ${SCRIPT_PATH}/../log)
export MLP_SCRIPT_NAME=$(basename $0)
export MLP_LOG_TIMESTAMP=$(date +%s)

export MLP_LOG_FILE=${log_directory}/${MLP_LOG_TIMESTAMP}-${MLP_LOG_FILE_PREFIX}${MLP_SCRIPT_NAME}.log
touch ${MLP_LOG_FILE}

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1> >(tee -i ${MLP_LOG_FILE})

echo_bold "A log file is available at '${MLP_LOG_FILE}'"

# Set additional environment variable
export MLP_BASE_DIR=$(realpath "${SCRIPT_PATH}/../..")
export MLP_LOCK_DIR="${MLP_BASE_DIR}/test/scripts/locks"

# Set local_error to 0
local_error=0
