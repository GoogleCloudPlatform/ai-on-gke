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
index=${7}
sleep_time=20
sleep_index=$((${index}+1))
sleep_total=$((${sleep_time}*${sleep_index}))
sleep $sleep_total
random=$(echo $RANDOM | md5sum | head -c 20; echo)
log="$(pwd)/log"
flag=0
#github_token=${7}
#echo "${github_token}" >> log
#echo "${TF_VAR_github_token}" >> log
#ls -lrt >> log
#ls -lrt ../ >> log
#TIMESTAMP=$(date "+%Y%m%d%H%M%S")
download_acm_repo_name=$(echo ${acm_repo_name} | awk -F "/" '{print $2}')-${random}
git config --global user.name ${github_user}
git config --global user.email ${github_emai}
git clone https://${github_user}:${TF_VAR_github_token}@github.com/${acm_repo_name} ${download_acm_repo_name}
echo "Download repo is ${download_acm_repo_name}" >> ${log}
echo "ls -lrt before going into download repo is $(ls -lrt)" >> ${log}
cd ${download_acm_repo_name}
echo "ls -lrt in download repo is $(ls -lrt)" >> ${log}
if [ ! -d "manifests" ] && [ ! -d "templates" ]; then
  echo "copying files" >> ${log}
  cp -r ../templates/acm-template/* .
  flag=1
fi
cd manifests/clusters
if [ ${flag} -eq 0 ]; then
  echo "not copying files" >> ${log}
fi
echo "In directory $(pwd)" >> ${log}
echo "level0 $(ls -lrt)" >> ${log}
echo "level1 $(ls -lrt ../)"  >> ${log}
echo "level2 $(ls -lrt ../../)"  >> ${log}
echo "level3 $(ls -lrt ../../../)"  >> ${log}
echo "level4 $(ls -lrt ../../../../ )" >> ${log}
echo "env is ${cluster_env}" >> ${log}

cp ../../templates/_cluster-template/cluster.yaml ./${cluster_name}-cluster.yaml
cp ../../templates/_cluster-template/selector.yaml ./${cluster_env}-selector.yaml
#cp ../../templates/_cluster-template/connect-gateway-rbac.yaml ./${cluster_name}-connect-gateway-rbac.yaml


find . -type f -name ${cluster_name}-cluster.yaml -exec  sed -i "s/CLUSTER_NAME/${cluster_name}/g" {} +
find . -type f -name ${cluster_name}-cluster.yaml -exec  sed -i "s/ENV/${cluster_env}/g" {} +
find . -type f -name ${cluster_env}-selector.yaml -exec  sed -i "s/ENV/${cluster_env}/g" {} +
#find . -type f -name ${cluster_name}-connect-gateway-rbac.yaml -exec  sed -i "s/CLUSTER_NAME/${cluster_name}/g" {} +
#find . -type f -name ${cluster_name}-connect-gateway-rbac.yaml -exec  sed -i "s/ENV/${cluster_env}/g" {} +

cp ../../templates/_cluster-template/kuberay .

git add ../../.
git config --global user.name ${github_user}
git config --global user.email ${github_email}
git commit -m "Adding ${cluster_name} cluster to the ${cluster_env} environment."
git push origin

cd ..
rm -rf ${download_acm_repo_name}
