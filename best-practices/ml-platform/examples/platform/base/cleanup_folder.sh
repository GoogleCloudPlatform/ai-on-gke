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

SCRIPT_PATH="$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)"

echo "Deleting the following folders and files:"
find ${SCRIPT_PATH} -type d -name .terraform -exec rm -rv {} \;
find ${SCRIPT_PATH} -type f -name .terraform.lock.hcl -delete -print
find ${SCRIPT_PATH} -type f -name tfplan -delete -print

exit 0
