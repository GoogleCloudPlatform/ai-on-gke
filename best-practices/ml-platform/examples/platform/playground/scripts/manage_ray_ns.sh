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

cd ${GIT_REPOSITORY_PATH}/manifests/clusters/kuberay

ns_exists=$(grep ${K8S_NAMESPACE} values.yaml | wc -l)
if [ "${ns_exists}" -ne 0 ]; then
  echo "namespace '${K8S_NAMESPACE}' already present in values.yaml"
  exit 0
fi

sed -i "s/watchNamespace:/watchNamespace:\n  - ${K8S_NAMESPACE}/g" values.yaml

git add .
git commit -m "Configured KubeRay operator to watch '${K8S_NAMESPACE}' namespace"
git push origin
