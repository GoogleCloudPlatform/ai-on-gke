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
namespace_template_directory="templates/_namespace_template"
namespace_template_path="${GIT_REPOSITORY_PATH}/${namespace_template_directory}"

if [ ! -d "${namespace_path}" ]; then
  echo "${K8S_NAMESPACE} folder doesnt exist in the configsync repo"
  exit 100
fi

if [ -f "${namespace_path}/kustomization.yaml" ]; then
  echo "${K8S_NAMESPACE} is already set up"
  exit 0
fi

cp -r ${namespace_template_path}/app/* ${namespace_path}/
sed -i "s?NAMESPACE?${K8S_NAMESPACE}?g" ${namespace_path}/*
sed -i "s?KUBERNETES_SERVICE_ACCOUNT_RAY_HEAD?${K8S_SERVICE_ACCOUNT_HEAD}?g" ${namespace_path}/*
sed -i "s?KUBERNETES_SERVICE_ACCOUNT_RAY_WORKER?${K8S_SERVICE_ACCOUNT_WORKER}?g" ${namespace_path}/*

# Add, commit, and push changes to the repository
cd ${GIT_REPOSITORY_PATH}
git add .
git commit -m "Manifests for RayCluster in '${K8S_NAMESPACE}' namespace"
git push origin
