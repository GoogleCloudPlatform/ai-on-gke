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

function cleanup() {
  echo "Removing ${repository_path}"
  rm -rf ${repository_path}
}
trap cleanup EXIT

random_suffix=$(echo $RANDOM | md5sum | head -c 20)
repository_path="/tmp/$(echo ${GIT_REPOSITORY} | awk -F "/" '{print $2}')-${random_suffix}"

git config --global user.name "${GIT_USERNAME}"
git config --global user.email "${GIT_EMAIL}"
git clone https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/${GIT_REPOSITORY} ${repository_path} || {
  echo "Failed to clone git repository '${GIT_REPOSITORY}'"
  exit 1
}

team_namespace_directory="manifests/apps/${K8S_NAMESPACE}"
team_namespace_path="${repository_path}/${team_namespace_directory}"

cd "${team_namespace_path}/.." || {
  echo "Team namespace directory '${team_namespace_directory}' does not exist"
}

git rm -rf ${team_namespace_path}

cluster_directory="manifests/clusters"
cluster_path="${repository_path}/${cluster_directory}"

cd "${cluster_path}" || {
  echo "Cluster directory '${cluster_directory}' does not exist"
  exit 3
}

git rm -rf ${cluster_path}/${K8S_NAMESPACE}/*
touch
sed -i "/- .\/${K8S_NAMESPACE}/d" ${cluster_path}/kustomization.yaml
sed -i "/  - ${K8S_NAMESPACE}/d" ${cluster_path}/kuberay/values.yaml

git config --global user.name ${GIT_USERNAME}
git config --global user.email ${GIT_EMAIL}
git add .
git commit -m "Removed manifests for ${K8S_NAMESPACE} namespace"
git push origin

${SCRIPT_PATH}/helpers/wait_for_root_sync.sh $(git rev-parse HEAD)

echo "Deleteing the namespace '${K8S_NAMESPACE}'..."
kubectl --namespace ${K8S_NAMESPACE} delete all --all
kubectl delete namespace ${K8S_NAMESPACE}
echo "Namespace '${K8S_NAMESPACE}', deleted"

rm -rf ${repository_path}
