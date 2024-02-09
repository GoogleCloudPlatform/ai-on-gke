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
project_id = "ai-on-gke-jss-sandbox"

## this is required for terraform to connect to GKE master and deploy workloads
cluster_name     = "ml-cluster"
cluster_location = "us-central1"

#######################################################
####    APPLICATIONS
#######################################################

## GKE environment variables
ray_namespace            = "ml"
gcp_service_account_gcs  = "ray-gcp-gcs"
gcp_service_account_prom = "ray-gcp-prom"
k8s_service_account      = "default"
gcs_bucket               = "ml-bucket"
create_ray_cluster       = true