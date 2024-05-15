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
if [ -f "kustomization.yaml" ]; then
  exit 0
fi

yamlfiles=$(find . -type f -name "*.yaml")
cp ../../templates/_cluster_template/kustomization.yaml .
for yamlfile in $(echo ${yamlfiles}); do
  cat <<EOF >>kustomization.yaml
- ${yamlfile}
EOF
done

cp -r ../../templates/_cluster_template/kuberay .
git add .
git commit -m "Added manifests to install kuberay operator."
git push origin
