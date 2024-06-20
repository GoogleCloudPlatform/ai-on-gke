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

generated_manifests_directory="${SCRIPT_PATH}/../manifests/${ENVIRONMENT_NAME}/${K8S_NAMESPACE}/gateway"
cp -pr ${generated_manifests_directory} ${namespace_path}/

# Added entries to the kustomization file
resources=$(find ${namespace_path} -maxdepth 1 -mindepth 1 -type d | sort)
resources+=" "
export resources+=$(find ${namespace_path} -maxdepth 1 -type f -name "*.yaml" ! -name "kustomization.yaml" ! -name "*values.yaml" | sort)
export kustomization_file=${namespace_path}/kustomization.yaml
source ${SCRIPT_PATH}/helpers/add_to_kustomization.sh

# Add, commit, and push changes to the repository
cd ${GIT_REPOSITORY_PATH}
git add .
git commit -m "Manifests for ${K8S_NAMESPACE} gateway"
git push origin
