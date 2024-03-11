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
gke_cluster=${1}
project_id=${2}
git_user=${3}
namespace=${4}
index=${5}
sleep_time=60
sleep_index=$((${index}+1))
sleep_total=$((${sleep_time}*${sleep_index}))
sleep $sleep_total
gcloud container fleet memberships get-credentials  ${gke_cluster} --project ${project_id}
ns_exists=$(kubectl get ns ${namespace} -o name | awk -F '/' '{print $2}')

while [ "${ns_exists}" != "${namespace}" ]
do
sleep 10
ns_exists=$(kubectl get ns ${namespace} -o name | awk -F '/' '{print $2}')
done
secret_exists=$(kubectl get secret git-creds -n ${namespace} -o name)
if [[ "${secret_exists}" == "secret/git-creds" ]]; then
  exit 0
else
  kubectl create secret generic git-creds --namespace="${namespace}" --from-literal=username="${git_user}"  --from-literal=token="${TF_VAR_github_token}"
fi