#!/bin/bash
#
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
set -u

SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)"

command=(gcloud anthos config controller delete "${NAME}")

if [ ! -z "${LOCATION}" ]; then
    command+=(--location=${LOCATION})
fi

if [ ! -z "${PROJECT_ID}" ]; then
    command+=(--project=${PROJECT_ID})
fi

command+=(--quiet)

echo "${command[@]}"
"${command[@]}"
