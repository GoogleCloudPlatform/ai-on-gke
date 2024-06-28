# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if [ -z "$PROJECT_ID" ]; then
    echo "Must provide PROJECT_ID in environment" 1>&2
    exit 2;
fi

if [ -z "$CLUSTER_NAME" ]; then
    echo "Must provide CLUSTER_NAME in environment" 1>&2
    exit 2;
fi

# Adapted from https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.10.0/examples/frontend.yaml
PROMETHEUS_FRONTEND_MANIFEST="$(cat ./deployment-frontend.json)"
PROMETHEUS_SERVICE_MANIFEST="$(cat ./service-prometheus.json)"

PROMETHEUS_FRONTEND_MANIFEST="$(echo "$PROMETHEUS_FRONTEND_MANIFEST" \
  | jq \
      --arg PROJECT_ID_ARG "--query.project-id=$PROJECT_ID" \
      '.spec.template.spec.containers[0].args += [$PROJECT_ID_ARG]' \
    )"

echo $PROMETHEUS_FRONTEND_MANIFEST | kubectl apply -f -
echo $PROMETHEUS_SERVICE_MANIFEST | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

if [ -z "$PROMETHEUS_HELM_VALUES_FILE" ]
    helm install jetstream prometheus-community/prometheus-adapter
else
    helm install jetstream prometheus-community/prometheus-adapter -f "$PROMETHEUS_HELM_VALUES_FILE"
fi