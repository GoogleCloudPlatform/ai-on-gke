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

random=$(
  echo $RANDOM | md5sum | head -c 20
  echo
)
download_acm_repo_name="/tmp/$(echo ${configsync_repo_name} | awk -F "/" '{print $2}')-${random}"
git config --global user.name ${github_user}
git config --global user.email ${github_emai}
git clone https://${github_user}:${GIT_TOKEN}@github.com/${configsync_repo_name} ${download_acm_repo_name} || exit 1
cd ${download_acm_repo_name}/manifests/clusters/kuberay
ns_exists=$(grep ${namespace} values.yaml | wc -l)
if [ "${ns_exists}" -ne 0 ]; then
  echo "namespace already present in values.yaml"
  exit 0
fi

sed -i "s/watchNamespace:/watchNamespace:\n  - ${namespace}/g" values.yaml

git add .
git config --global user.name ${github_user}
git config --global user.email ${github_email}
git commit -m "Configured KubeRay operator to watch '${namespace}' namespace."
git push origin

rm -rf ${download_acm_repo_name}
