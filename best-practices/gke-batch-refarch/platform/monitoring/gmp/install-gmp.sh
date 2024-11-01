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

[[ ! "${PROJECT_ID}" ]] && echo -e "Please export PROJECT_ID variable (export PROJECT_ID=<YOUR POROJECT ID>)\nExiting." && exit 0
echo -e "PROJECT_ID is set to ${PROJECT_ID}"

[[ ! "${REGION}" ]] && echo -e "Please export REGION variable (export REGION=<YOUR REGION, eg: us-central1>)\nExiting." && exit 0
echo -e "REGION is set to ${REGION}"

kubectl apply -f gmp-kueue-monitoring.yaml && \
gcloud monitoring dashboards create --project=${PROJECT_ID} --config-from-file=kueue-dashboard.json
