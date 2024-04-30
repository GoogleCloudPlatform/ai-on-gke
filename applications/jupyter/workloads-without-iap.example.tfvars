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
## Need to pull this variables from tf output from previous infrastructure stage
project_id = "<gcp-prj-id>"

## this is required for terraform to connect to GKE master and deploy workloads
create_cluster        = false # this flag will create a new standard public gke cluster in default network
cluster_name          = "<cluster-name>"
cluster_location      = "us-central1"
cluster_membership_id = "" # required only for private clusters, default: cluster_name

#######################################################
####    APPLICATIONS
#######################################################

## JupyterHub variables
kubernetes_namespace              = "ai-on-gke"
gcs_bucket                        = "<gcs-bucket>"
create_gcs_bucket                 = true
workload_identity_service_account = "jupyter-service-account"

# JupyterHub without IAP
add_auth = false
