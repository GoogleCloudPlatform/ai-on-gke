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
project_id = "akvelon-gke-aieco"

## this is required for terraform to connect to GKE master and deploy workloads
create_cluster   = true # this flag will create a new standard public gke cluster in default network
cluster_name     = "flyte-test"
cluster_location = "us-central1"

# gpu_pools = [ {
#   name                = "gpu-pool"
#   queued_provisioning = true
#   machine_type        = "g2-standard-24"
#   disk_type           = "pd-balanced"
#   autoscaling         = true
#   min_count           = 0
#   max_count           = 3
#   initial_node_count  = 0
# } ]

#######################################################
####    APPLICATIONS
#######################################################
# Creates a google service account & k8s service account & configures workload identity with appropriate permissions.
# Set to false & update the variable `workload_identity_service_account` to use an existing IAM service account.
create_service_account = false

#DISABLE IAP
create_brand = false

autopilot_cluster = true
enable_gpu = true
#kubernetes_version = "1.31.1-gke.2105000"

create_gcs_bucket = true
gcs_bucket = "vdjerek-flyte-bucket"