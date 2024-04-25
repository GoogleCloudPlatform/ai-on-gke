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

cd "${team_namespace_path}" || {
  echo "Team namespace directory '${team_namespace_directory}' does not exist"
  exit 2
}

generated_manifests_directory="${SCRIPT_PATH}/../manifests/${K8S_NAMESPACE}/gateway"
cp -pr ${generated_manifests_directory} ${team_namespace_path}/

resources=$(find ${team_namespace_path} -maxdepth 1 -mindepth 1 -type d)
resources+=" "
resources+=$(find ${team_namespace_path} -maxdepth 1 -type f -name "*.yaml" ! -name "kustomization.yaml" ! -name "*values.yaml")
for resource in ${resources}; do
  resource_basename=$(basename ${resource})

  if [ -d "${resource}" ]; then
    resource_entry="./${resource_basename}"
  elif [ -f "${resource}" ]; then
    resource_entry="${resource_basename}"
  else
    echo "${resource} is not a directory or file"
    exit 3
  fi

  grep -qx "\- ${resource_entry}" ${team_namespace_path}/kustomization.yaml || echo "- ${resource_entry}" >>${team_namespace_path}/kustomization.yaml
done

cd "${team_namespace_path}"
git config --global user.name ${GIT_USERNAME}
git config --global user.email ${GIT_EMAIL}
git add .
git commit -m "Manifests for ${K8S_NAMESPACE} gateway"
git push origin

rm -rf ${repository_path}
