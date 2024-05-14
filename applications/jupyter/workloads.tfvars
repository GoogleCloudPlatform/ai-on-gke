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
project_id = "<your project ID>"

## This is required for terraform to connect to GKE cluster and deploy workloads.
cluster_name     = "ml-cluster"
cluster_location = "us-central1"

## If terraform should create a new GKE cluster, fill in this section as well.
##    By default, a public autopilot GKE cluster will be created in the default network.
##    Set the autopilot_cluster variable to false to create a standard cluster instead.
create_cluster        = false
autopilot_cluster     = true
cluster_membership_id = "" # required for private cluster, defaults to `cluster_name`

#######################################################
####    APPLICATIONS
#######################################################

## JupyterHub variables
kubernetes_namespace              = "ai-on-gke"
create_gcs_bucket                 = true
gcs_bucket                        = "gcs-bucket-<unique-suffix>" # Choose a globally unique bucket name.
workload_identity_service_account = "jupyter-sa"

# IAP Configs
create_brand  = false
support_email = "<email>" ## specify if create_brand=true

# JupyterHub with IAP
add_auth                 = false
k8s_ingress_name         = "jupyter-ingress"
k8s_managed_cert_name    = "jupyter-managed-cert"
k8s_iap_secret_name      = "jupyter-iap-secret"
k8s_backend_config_name  = "jupyter-iap-config"
k8s_backend_service_name = "proxy-public"
k8s_backend_service_port = 80

domain            = "jupyter.example.com" ## Provide domain for ingress resource and ssl certificate. 
client_id         = ""                    ## Ensure brand is Internal, to autogenerate client credentials
client_secret     = ""
members_allowlist = "user:<email>,group:<email>,serviceAccount:<email>,domain:google.com"

