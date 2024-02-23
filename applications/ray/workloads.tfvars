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
project_id = "<your project ID>"

## this is required for terraform to connect to GKE master and deploy workloads
cluster_name     = "<your project ID>"
cluster_location = "us-central1"

#######################################################
####    APPLICATIONS
#######################################################

## GKE environment variables

## GKE environment variables
ray_namespace = "ml"

# Creates a google service account & k8s service account & configures workload identity with appropriate permissions.
# Set to false & update the variable `gcp_service_account` to use an existing IAM service account.
create_service_account = true
gcp_service_account    = "ray-service-account"

# Bucket name should be globally unique.
gcs_bucket                      = "ray-bucket-zydg"
create_ray_cluster              = true
enable_grafana_on_ray_dashboard = false
