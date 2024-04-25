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
google_service_account_head=${6}
kubernetes_service_account_head=${7}
google_service_account_worker=${8}
kubernetes_service_account_worker=${9}

random=$(
  echo $RANDOM | md5sum | head -c 20
  echo
)
download_acm_repo_name="/tmp/$(echo ${configsync_repo_name} | awk -F "/" '{print $2}')-${random}"
git config --global user.name ${github_user}
git config --global user.email ${github_emai}
git clone https://${github_user}:${GIT_TOKEN}@github.com/${configsync_repo_name} ${download_acm_repo_name} || exit 1
cd ${download_acm_repo_name}/manifests/apps
if [ ! -d "${namespace}" ]; then
  echo "${namespace} folder doesnt exist in the configsync repo"
  exit 1
fi

if [ -f "${namespace}/kustomization.yaml" ]; then
  echo "${namespace} is already set up"
  exit 0
fi

cp -r ../../templates/_namespace_template/app/* ${namespace}/
sed -i "s?NAMESPACE?${namespace}?g" ${namespace}/*
sed -i "s?GOOGLE_SERVICE_ACCOUNT_RAY_HEAD?$google_service_account_head?g" ${namespace}/*
sed -i "s?KUBERNETES_SERVICE_ACCOUNT_RAY_HEAD?$kubernetes_service_account_head?g" ${namespace}/*
sed -i "s?GOOGLE_SERVICE_ACCOUNT_RAY_WORKER?$google_service_account_worker?g" ${namespace}/*
sed -i "s?KUBERNETES_SERVICE_ACCOUNT_RAY_WORKER?$kubernetes_service_account_worker?g" ${namespace}/*

git add .
git config --global user.name ${github_user}
git config --global user.email ${github_email}
git commit -m "Installing ray cluster in ${namespace} namespace."
git push origin

rm -rf ${download_acm_repo_name}
