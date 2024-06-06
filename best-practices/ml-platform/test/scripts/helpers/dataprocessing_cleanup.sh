#!/usr/bin/env bash

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

echo_title "Removing IAM permissions"

gcloud projects remove-iam-policy-binding ${MLP_PROJECT_ID} \
    --member "serviceAccount:wi-ml-team-ray-head@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/storage.objectViewer

gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member "serviceAccount:wi-ml-team-ray-worker@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/storage.objectAdmin

echo_title "Deleting data processing Artifact Registry repository"

gcloud artifacts repositories delete dataprocessing \
    --location=us \
    --project=${PROJECT_ID} \
    --quiet

echo_title "Deleting dataprocessing GCS buckets"

gsutil -m -q rm -rf gs://${PROCESSING_BUCKET}/*
gcloud storage buckets delete gs://${PROCESSING_BUCKET} --project ${PROJECT_ID}

gsutil -m -q rm -rf gs://${PROJECT_ID}_cloudbuild/*
gcloud storage buckets delete gs://${PROJECT_ID}_cloudbuild --project ${PROJECT_ID}
