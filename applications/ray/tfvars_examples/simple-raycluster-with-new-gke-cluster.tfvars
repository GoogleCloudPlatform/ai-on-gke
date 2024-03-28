# Copyright 2023 Google LLC
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


##common variables
## Need to pull this variables from tf output from previous platform stage
project_id = "<your-project-id>"

## this is required for terraform to connect to GKE master and deploy workloads
create_cluster   = true # this flag will create a new standard public gke cluster in default network
cluster_name     = "<your-cluster>"
cluster_location = "<your-cluster-location>"

#######################################################
####    APPLICATIONS
#######################################################

## GKE environment variables
kubernetes_namespace = "ray"

# Creates a google service account & k8s service account & configures workload identity with appropriate permissions.
# Set to false & update the variable `workload_identity_service_account` to use an existing IAM service account.
create_service_account = false

# Bucket name should be globally unique.
create_gcs_bucket               = true
gcs_bucket                      = "<add-your-bucket>"
enable_grafana_on_ray_dashboard = false
