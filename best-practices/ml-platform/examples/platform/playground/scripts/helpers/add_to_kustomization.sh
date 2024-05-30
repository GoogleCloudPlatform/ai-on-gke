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

if [ ! -f ${kustomization_file} ]; then
  echo "${kustomization_file} not found"
  exit 2
fi

for resource in ${resources}; do
  resource_basename=$(basename ${resource})

  if [ -d "${resource}" ]; then
    resource_entry="./${resource_basename}"
  elif [ -f "${resource}" ]; then
    resource_entry="${resource_basename}"
  else
    echo "${resource} is not a directory or file"
    exit 3
  fi

  grep -qx "\- ${resource_entry}" ${kustomization_file} || echo "- ${resource_entry}" >>${kustomization_file}
done
