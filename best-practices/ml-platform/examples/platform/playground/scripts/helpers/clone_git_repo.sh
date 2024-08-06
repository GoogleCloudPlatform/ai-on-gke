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

function cleanup() {
    echo "Removing ${GIT_REPOSITORY_PATH}"
    rm -rf ${GIT_REPOSITORY_PATH}
}
trap cleanup EXIT

random_suffix=$(echo $RANDOM | md5sum | head -c 20)
export GIT_REPOSITORY_PATH="/tmp/$(basename ${GIT_REPOSITORY})-${random_suffix}"

git clone https://${GIT_USERNAME}:${GIT_TOKEN}@${GIT_REPOSITORY} ${GIT_REPOSITORY_PATH} || {
    echo "Failed to clone git repository '${GIT_REPOSITORY}'"
    exit 1
}
cd ${GIT_REPOSITORY_PATH}

git config user.name "${GIT_USERNAME}"
git config user.email "${GIT_EMAIL}"

cd -
