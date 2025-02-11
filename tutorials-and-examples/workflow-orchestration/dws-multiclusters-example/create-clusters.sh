#!/bin/bash

# Copyright 2024 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

echo 'Create GKE Autopilot clusters'

KUEUE_VERSION=v0.8.1
regions=("europe-west4" "asia-southeast1" "us-east4" "europe-west4")
kubeconfigs=("manager-europe-west4" "worker-asia-southeast1" "worker-us-east4" "worker-eu-west4")
PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
PREFIX_MANAGER="man"
PREFIX_WORKER="w"
JOBSET_VERSION=v0.6.0

# Loop through the regions
for i in "${!regions[@]}"; do
    region="${regions[$i]}"
    echo "$region"
    # Construct the cluster name, adding "manager" if it's the first region
    if [[ $i -eq 0 ]]; then
        cluster_name="$PREFIX_MANAGER-$region"
    else
        cluster_name="$PREFIX_WORKER-$region"
    fi

    #Create the cluster
    gcloud container clusters create-auto "$cluster_name" \
        --project "$PROJECT_ID" \
        --region "$region" \
        --release-channel "regular" \
        --async
done
for i in "${!regions[@]}"; do
    region="${regions[$i]}"
    if [[ $i -eq 0 ]]; then
        cluster_name="$PREFIX_MANAGER-$region"
    else
        cluster_name="$PREFIX_WORKER-$region"
    fi

    opId=$(gcloud container operations list --filter "TARGET=https://container.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/$region/clusters/$cluster_name" --format="value(name)")
    gcloud container operations wait "$opId" --project "$PROJECT_ID" --region "$region"
    set +e
    until gcloud -q container clusters get-credentials "$cluster_name" \
        --project "$PROJECT_ID" \
        --region "$region"; do
        echo "GKE Cluster is provisioning. Retrying in 15 seconds..."
        sleep 15
    done
    set -e
    configname="${kubeconfigs[$i]}"
    kubectl config rename-context "gke_$PROJECT_ID"_"$region"_"$cluster_name" "$configname"
done
