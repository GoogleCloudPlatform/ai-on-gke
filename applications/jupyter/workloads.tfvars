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
create_cluster    = false # Create a GKE cluster in the specified network.
autopilot_cluster = true
private_cluster   = false
cluster_name      = "ml-cluster2021"
cluster_location  = "us-central1"
create_network    = true
network_name      = "ml-network2021"
subnetwork_cidr   = "10.100.0.0/16"

#######################################################
####    APPLICATIONS
#######################################################

## JupyterHub variables
kubernetes_namespace              = "ml"
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

domain            = "" ## Provide domain for ingress resource and ssl certificate. If it's empty, it will use nip.io wildcard dns
client_id         = "" ## Ensure brand is Internal, to autogenerate client credentials
client_secret     = ""
members_allowlist = "user:<email>,group:<email>,serviceAccount:<email>,domain:google.com"

