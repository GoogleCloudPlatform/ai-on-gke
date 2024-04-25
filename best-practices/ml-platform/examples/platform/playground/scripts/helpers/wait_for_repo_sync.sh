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

LAST_COMMIT=${LAST_COMMIT:-${1}}

last_synced_commit=$(kubectl get reposync ${REPO_SYNC_NAME} -n ${REPO_SYNC_NAMESPACE} --output go-template='{{.status.lastSyncedCommit}}')
while [[ ${last_synced_commit} != ${LAST_COMMIT} ]]; do
    echo "Waiting for reposync '${REPO_SYNC_NAME}' in namespace '${REPO_SYNC_NAMESPACE}' to synchronize..."
    sleep 10
    last_synced_commit=$(kubectl get reposync ${REPO_SYNC_NAME} -n ${REPO_SYNC_NAMESPACE} --output go-template='{{.status.lastSyncedCommit}}')
done

echo "reposync '${REPO_SYNC_NAME}' has synchronize"
