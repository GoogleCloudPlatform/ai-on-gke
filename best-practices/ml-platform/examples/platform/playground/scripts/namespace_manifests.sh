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
clusters_namespace_directory="${clusters_directory}/${K8S_NAMESPACE}"
clusters_namespace_path="${GIT_REPOSITORY_PATH}/${clusters_namespace_directory}"
namespace_directory="manifests/apps/${K8S_NAMESPACE}"
namespace_path="${GIT_REPOSITORY_PATH}/${namespace_directory}"
cluster_template_directory="templates/_cluster_template"
cluster_template_path="${GIT_REPOSITORY_PATH}/${cluster_template_directory}"

chars_in_namespace=$(echo -n ${K8S_NAMESPACE} | wc -c)
chars_in_cluster_env=$(echo -n ${CLUSTER_ENV} | wc -c)
chars_in_reposync_name=$(expr ${chars_in_namespace} + ${chars_in_cluster_env} + 1)

# Create clusters namespace directory
mkdir ${clusters_namespace_path}

# Copy template files to clusters namespace directory
cp -r ${cluster_template_path}/team/* ${clusters_namespace_path}

# Configure template files in clusters namespace directory
sed -i "s?NAMESPACE?${K8S_NAMESPACE}?g" ${clusters_namespace_path}/*
sed -ni '/#END OF SINGLE ENV DECLARATION/q;p' ${clusters_namespace_path}/reposync.yaml
sed -i "s?ENV?${CLUSTER_ENV}?g" ${clusters_namespace_path}/reposync.yaml
sed -i "s?GIT_REPO?https://${GIT_REPOSITORY}?g" ${clusters_namespace_path}/reposync.yaml
sed -i "s?<NUMBER_OF_CHARACTERS_IN_REPOSYNC_NAME>?${chars_in_reposync_name}?g" ${clusters_namespace_path}/reposync.yaml

# Create the namespace directory
mkdir ${namespace_path}
touch ${namespace_path}/.gitkeep

# Added entries to the kustomization file
export resources=("${clusters_namespace_path}")
export kustomization_file="${clusters_path}/kustomization.yaml"
source ${SCRIPT_PATH}/helpers/add_to_kustomization.sh

# Add, commit, and push changes to the repository
cd ${GIT_REPOSITORY_PATH}
git add .
git commit -m "Manifests for '${K8S_NAMESPACE}' namespace"
git push origin
