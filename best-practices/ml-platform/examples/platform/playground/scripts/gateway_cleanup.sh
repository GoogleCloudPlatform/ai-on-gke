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

# Set directory and path variables
namespace_directory="manifests/apps/${K8S_NAMESPACE}"
namespace_path="${GIT_REPOSITORY_PATH}/${namespace_directory}"

cd "${namespace_path}" || {
  echo "Namespace directory '${namespace_directory}' does not exist"
  exit 100
}

git rm -rf ${namespace_path}/gateway
sed -i '/- .\/gateway/d' ${namespace_path}/kustomization.yaml

# Add, commit, and push changes to the repository
cd ${GIT_REPOSITORY_PATH}
git add .
git commit -m "Removed manifests for '${K8S_NAMESPACE}' gateway"
git push origin

${SCRIPT_PATH}/helpers/wait_for_repo_sync.sh $(git rev-parse HEAD)

kubectl delete --namespace ${K8S_NAMESPACE} --all gcpbackendpolicy
kubectl delete --namespace ${K8S_NAMESPACE} --all httproute
kubectl delete --namespace ${K8S_NAMESPACE} --all gateway
