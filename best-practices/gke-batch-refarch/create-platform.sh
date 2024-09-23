#!/usr/bin/env bash

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

[[ ! "${PROJECT_ID}" ]] && echo -e "Please export PROJECT_ID variable (\e[95mexport PROJECT_ID=<YOUR PROJECT ID>\e[0m)\nExiting." && exit 0
echo -e "\e[95mPROJECT_ID is set to ${PROJECT_ID}\e[0m"

[[ ! "${REGION}" ]] && echo -e "Please export REGION variable (\e[95mexport REGION=<YOUR REGION, eg: us-central1>\e[0m)\nExiting." && exit 0
echo -e "\e[95mREGION is set to ${REGION}\e[0m"

[[ ! "${ZONE}" ]] && echo -e "Please export ZONE variable (\e[95mexport ZONE=<YOUR ZONE, eg: us-central1-c >\e[0m)\nExiting." && exit 0
echo -e "\e[95mZONE is set to ${ZONE}\e[0m"

gcloud config set core/project ${PROJECT_ID} &&
  export PROJECT_NUM=$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)') &&
  export TF_CLOUDBUILD_SA="${PROJECT_NUM}@cloudbuild.gserviceaccount.com" &&
  echo -e "$TF_CLOUDBUILD_SA" &&
  echo -e "\e[95mEnabling required APIs in ${PROJECT_ID}\e[0m" &&
  gcloud --project="${PROJECT_ID}" services enable \
    cloudapis.googleapis.com \
    containerfilesystem.googleapis.com \
    compute.googleapis.com \
    servicenetworking.googleapis.com \
    iam.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    container.googleapis.com \
    monitoring.googleapis.com \
    logging.googleapis.com \
    storage.googleapis.com \
    cloudresourcemanager.googleapis.com &&
  echo -e "\e[95mAssigning Cloudbuild Service Account roles/owner in ${PROJECT_ID}\e[0m" &&
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" --member serviceAccount:"${TF_CLOUDBUILD_SA}" --role roles/owner --condition=None &&
  echo -e "\e[95mStarting Cloudbuild to create infrastructure...\e[0m" &&
  if ! gcloud --quiet --no-user-output-enabled artifacts repositories describe tutorial-installer --location=${REGION} &>/dev/null; then
    gcloud artifacts repositories create tutorial-installer --repository-format=docker --location=${REGION} --description="Repo for platform installer container images built by Cloud Build."
  fi

cd "${SCRIPT_PATH}/.."
gcloud builds submit \
  --async \
  --config gke-batch-refarch/cloudbuild-create.yaml \
  --ignore-file gke-batch-refarch/cloudbuild-ignore \
  --project="${PROJECT_ID}" \
  --substitutions _REGION=${REGION},_ZONE=${ZONE} &&
  echo -e "\e[95mYou can view the Cloudbuild status through https://console.cloud.google.com/cloud-build/builds;region=global?project=${PROJECT_ID}\e[0m"

cd -
