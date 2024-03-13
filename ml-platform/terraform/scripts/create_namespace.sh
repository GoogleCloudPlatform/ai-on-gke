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

configsync_repo_name=${1}
github_email=${2}
github_org=${3}
github_user=${4}
namespace=${5}
cluster_env=${6}

logfile=$(pwd)/log
random=$(
  echo $RANDOM | md5sum | head -c 20
  echo
)
download_acm_repo_name="/tmp/$(echo ${configsync_repo_name} | awk -F "/" '{print $2}')-${random}"
git config --global user.name ${github_user}
git config --global user.email ${github_emai}
git clone https://${github_user}:${GIT_TOKEN}@github.com/${configsync_repo_name} ${download_acm_repo_name} || exit 1
cd ${download_acm_repo_name}/manifests/clusters

if [ -d "${namespace}" ]; then
  exit 0
fi

#TODO: This most likely needs to be fixed for multiple environments
chars_in_namespace=$(echo -n ${namespace} | wc -c)
chars_in_cluster_env=$(echo -n ${cluster_env} | wc -c)
chars_in_reposync_name=$(expr $chars_in_namespace + ${chars_in_cluster_env} + 1)
mkdir ${namespace} || exit 1
cp -r ../../templates/_cluster_template/team/* ${namespace}
sed -i "s?NAMESPACE?$namespace?g" ${namespace}/*
sed -ni '/#END OF SINGLE ENV DECLARATION/q;p' ${namespace}/reposync.yaml
sed -i "s?ENV?$cluster_env?g" ${namespace}/reposync.yaml
sed -i "s?GIT_REPO?https://github.com/$configsync_repo_name?g" ${namespace}/reposync.yaml
sed -i "s?<NUMBER_OF_CHARACTERS_IN_REPOSYNC_NAME>?$chars_in_reposync_name?g" ${namespace}/reposync.yaml

mkdir ../apps/${namespace}
touch ../apps/${namespace}/.gitkeep

cat <<EOF >>kustomization.yaml
- ./${namespace}
EOF
cd ..
git add .
git config --global user.name ${github_user}
git config --global user.email ${github_email}
git commit -m "Adding manifests to create a new namespace."
git push origin

rm -rf ${download_acm_repo_name}
