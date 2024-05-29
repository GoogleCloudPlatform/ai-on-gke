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

source ${SCRIPT_PATH}/helpers/clone_git_repo.sh

if [ ! -d "${GIT_REPOSITORY_PATH}/manifests" ] && [ ! -d "${GIT_REPOSITORY_PATH}/templates" ]; then
  echo "Copying template files..."
  cp -r templates/acm-template/* ${GIT_REPOSITORY_PATH}/
fi

cd ${GIT_REPOSITORY_PATH}/manifests/clusters || {
  echo "Failed to copy template files"
  exit 1
}

cp ../../templates/_cluster_template/cluster.yaml ./${CLUSTER_NAME}-cluster.yaml
cp ../../templates/_cluster_template/network-logging.yaml ./network-logging.yaml
cp ../../templates/_cluster_template/selector.yaml ./${CLUSTER_ENV}-selector.yaml

find . -type f -name ${CLUSTER_NAME}-cluster.yaml -exec sed -i "s/CLUSTER_NAME/${CLUSTER_NAME}/g" {} +
find . -type f -name ${CLUSTER_NAME}-cluster.yaml -exec sed -i "s/ENV/${CLUSTER_ENV}/g" {} +
find . -type f -name ${CLUSTER_ENV}-selector.yaml -exec sed -i "s/ENV/${CLUSTER_ENV}/g" {} +

git add ../../.
git commit -m "Added '${CLUSTER_NAME} 'cluster to the ${CLUSTER_ENV} environment."
git push origin
