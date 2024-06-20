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
clusters_directory="manifests/clusters"
clusters_path="${GIT_REPOSITORY_PATH}/${clusters_directory}"
namespace_directory="manifests/apps/${K8S_NAMESPACE}"
namespace_path="${GIT_REPOSITORY_PATH}/${namespace_directory}"

cd "${namespace_path}/.." || {
  echo "Team namespace directory '${namespace_directory}' does not exist"
}

git rm -rf ${namespace_path}

cd "${clusters_path}" || {
  echo "Clusters directory '${clusters_directory}' does not exist"
}

git rm -rf ${clusters_path}/${K8S_NAMESPACE}/*
sed -i "/- .\/${K8S_NAMESPACE}/d" ${clusters_path}/kustomization.yaml
sed -i "/  - ${K8S_NAMESPACE}/d" ${clusters_path}/kuberay/values.yaml

# Add, commit, and push changes to the repository
cd ${GIT_REPOSITORY_PATH}
git add .
git commit -m "Removed manifests for '${K8S_NAMESPACE}' namespace"
git push origin

${SCRIPT_PATH}/helpers/wait_for_root_sync.sh $(git rev-parse HEAD)

echo "Deleteing the namespace '${K8S_NAMESPACE}'..."
kubectl --namespace ${K8S_NAMESPACE} delete all --all
kubectl delete namespace ${K8S_NAMESPACE}
echo "Namespace '${K8S_NAMESPACE}', deleted"

echo "Cleaning up network endpoint groups..."
negs=$(gcloud compute network-endpoint-groups list --filter="name~'k8s.*-${K8S_NAMESPACE}-.*' AND network~'.*-${ENVIRONMENT_NAME}$'" --format='value(format("{0},{1}", name, zone.basename()))' --project=${PROJECT_ID})
for neg in ${negs}; do
    name="${neg%,*}"
    zone="${neg#*,}"

    echo "Deleting '${name}' network endpoint group in ${zone}..."
    gcloud compute network-endpoint-groups delete ${name} --project=${PROJECT_ID} --quiet --zone=${zone}
done
