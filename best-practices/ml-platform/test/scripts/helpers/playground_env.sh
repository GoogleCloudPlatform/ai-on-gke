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

export MLP_ENVIRONMENT_NAME=${MLP_ENVIRONMENT_NAME:-$(grep environment_name ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars | awk -F"=" '{print $2}' | xargs)}

export MLP_UNIQUE_IDENTIFIER="${MLP_PROJECT_ID}-${MLP_ENVIRONMENT_NAME}"

export MLP_STATE_BUCKET="${MLP_UNIQUE_IDENTIFIER}-terraform"
export TF_DATA_DIR=".terraform-${MLP_UNIQUE_IDENTIFIER}"

export MLP_ENVIRONMENT_FILE="${SCRIPTS_DIR}/environment_files/playground-${MLP_UNIQUE_IDENTIFIER}.env"

if [ -f ${MLP_ENVIRONMENT_FILE} ]; then
    cat ${MLP_ENVIRONMENT_FILE}
    source ${MLP_ENVIRONMENT_FILE}
fi
