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

cd ${GIT_REPOSITORY_PATH}/manifests/clusters

if [ -d "${K8S_NAMESPACE}" ]; then
  exit 0
fi

#TODO: This most likely needs to be fixed for multiple environments
chars_in_namespace=$(echo -n ${K8S_NAMESPACE} | wc -c)
chars_in_cluster_env=$(echo -n ${CLUSTER_ENV} | wc -c)
chars_in_reposync_name=$(expr ${chars_in_namespace} + ${chars_in_cluster_env} + 1)
mkdir ${K8S_NAMESPACE} || exit 1
cp -r ../../templates/_cluster_template/team/* ${K8S_NAMESPACE}
sed -i "s?NAMESPACE?${K8S_NAMESPACE}?g" ${K8S_NAMESPACE}/*
sed -ni '/#END OF SINGLE ENV DECLARATION/q;p' ${K8S_NAMESPACE}/reposync.yaml
sed -i "s?ENV?${CLUSTER_ENV}?g" ${K8S_NAMESPACE}/reposync.yaml
sed -i "s?GIT_REPO?https://${GIT_REPOSITORY}?g" ${K8S_NAMESPACE}/reposync.yaml
sed -i "s?<NUMBER_OF_CHARACTERS_IN_REPOSYNC_NAME>?${chars_in_reposync_name}?g" ${K8S_NAMESPACE}/reposync.yaml

mkdir ../apps/${K8S_NAMESPACE}
touch ../apps/${K8S_NAMESPACE}/.gitkeep

cat <<EOF >>kustomization.yaml
- ./${K8S_NAMESPACE}
EOF

cd ..
git add .
git commit -m "Added manifests to create '${K8S_NAMESPACE}' namespace"
git push origin
