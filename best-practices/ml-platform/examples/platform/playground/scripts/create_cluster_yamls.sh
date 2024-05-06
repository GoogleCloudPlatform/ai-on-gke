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

github_org=${1}
acm_repo_name=${2}
github_user=${3}
github_email=${4}
cluster_env=${5}
cluster_name=${6}

random=$(
  echo $RANDOM | md5sum | head -c 20
  echo
)

download_acm_repo_name="/tmp/$(echo ${acm_repo_name} | awk -F "/" '{print $2}')-${random}"
git clone https://${github_user}:${GIT_TOKEN}@github.com/${acm_repo_name} ${download_acm_repo_name} || {
  echo "Failed to clone git repository '${acm_repo_name}'"
  exit 1
}

if [ ! -d "${download_acm_repo_name}/manifests" ] && [ ! -d "${download_acm_repo_name}/templates" ]; then
  echo "Copying template files..."
  cp -r templates/acm-template/* ${download_acm_repo_name}/
fi

cd ${download_acm_repo_name}/manifests/clusters || {
  echo "Failed to copy template files"
  exit 1
}

git config user.name ${github_user}
git config user.email ${github_email}

cp ../../templates/_cluster_template/cluster.yaml ./${cluster_name}-cluster.yaml
cp ../../templates/_cluster_template/selector.yaml ./${cluster_env}-selector.yaml

find . -type f -name ${cluster_name}-cluster.yaml -exec sed -i "s/CLUSTER_NAME/${cluster_name}/g" {} +
find . -type f -name ${cluster_name}-cluster.yaml -exec sed -i "s/ENV/${cluster_env}/g" {} +
find . -type f -name ${cluster_env}-selector.yaml -exec sed -i "s/ENV/${cluster_env}/g" {} +

git add ../../.
git commit -m "Adding ${cluster_name} cluster to the ${cluster_env} environment."
git push origin

rm -rf ${download_acm_repo_name}
