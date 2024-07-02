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
cluster_template_directory="templates/_cluster_template"
cluster_template_path="${GIT_REPOSITORY_PATH}/${cluster_template_directory}"

cd "${clusters_path}" || {
    echo "Clusters directory '${clusters_directory}' does not exist"
    exit 100
}

mkdir -p ${clusters_path}/gmp-public
cp -pr ${cluster_template_path}/gmp-public/nvidia-dcgm ${clusters_path}/gmp-public/

# Added entries to the clusters/gmp-public kustomization file
resources=$(find ${clusters_path}/gmp-public -maxdepth 1 -mindepth 1 -type d | sort)
resources+=" "
export resources+=$(find ${clusters_path}/gmp-public -maxdepth 1 -type f -name "*.yaml" ! -name "kustomization.yaml" ! -name "*values.yaml" | sort)
export kustomization_file="${clusters_path}/gmp-public/kustomization.yaml"

if [ ! -f ${kustomization_file} ]; then
    cp -pr ${cluster_template_path}/gmp-public/kustomization.yaml ${clusters_path}/gmp-public/
fi

source ${SCRIPT_PATH}/helpers/add_to_kustomization.sh

# Added entries to the clusters kustomization file
resources=$(find ${clusters_path} -maxdepth 1 -mindepth 1 -type d | sort)
resources+=" "
export resources+=$(find ${clusters_path} -maxdepth 1 -type f -name "*.yaml" ! -name "kustomization.yaml" ! -name "*values.yaml" | sort)
export kustomization_file="${clusters_path}/kustomization.yaml"

source ${SCRIPT_PATH}/helpers/add_to_kustomization.sh

# Add, commit, and push changes to the repository
cd ${GIT_REPOSITORY_PATH}
git add .
git commit -m "Manifests for NVIDIA DCGM"
git push origin
