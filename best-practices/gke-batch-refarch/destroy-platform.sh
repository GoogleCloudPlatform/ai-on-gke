# Copyright 2023 Google LLC
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

SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)"

[[ ! "${PROJECT_ID}" ]] && echo -e "Please export PROJECT_ID variable (\e[95mexport PROJECT_ID=<YOUR POROJECT ID>\e[0m)\nExiting." && exit 0
echo -e "\e[95mPROJECT_ID is set to ${PROJECT_ID}\e[0m"

[[ ! "${REGION}" ]] && echo -e "Please export REGION variable (\e[95mexport REGION=<YOUR REGION, eg: us-central1>\e[0m)\nExiting." && exit 0
echo -e "\e[95mREGION is set to ${REGION}\e[0m"

[[ ! "${ZONE}" ]] && echo -e "Please export ZONE variable (\e[95mexport ZONE=<YOUR ZONE, eg: us-central1-c >\e[0m)\nExiting." && exit 0
echo -e "\e[95mZONE is set to ${ZONE}\e[0m"

gcloud config set core/project ${PROJECT_ID}

BUILD_SUBSTITUTIONS="_REGION=${REGION},_ZONE=${ZONE}"

if [[ -v ENVIRONMENT_NAME ]] && [[ ! -z "${ENVIRONMENT_NAME}" ]]; then
  BUILD_SUBSTITUTIONS+=",_ENVIRONMENT_NAME=${ENVIRONMENT_NAME}"
fi

cd "${SCRIPT_PATH}/.."
gcloud builds submit \
  --async \
  --config gke-batch-refarch/cloudbuild-destroy.yaml \
  --ignore-file gke-batch-refarch/cloudbuild-ignore \
  --project="${PROJECT_ID}" \
  --substitutions ${BUILD_SUBSTITUTIONS} &&
  echo -e "\e[95mYou can view the Cloudbuild status through https://console.cloud.google.com/cloud-build/builds;region=global?project=${PROJECT_ID}\e[0m"

cd -
