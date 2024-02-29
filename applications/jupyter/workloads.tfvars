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
cluster_name          = "ml-cluster"
cluster_location      = "us-central1"
cluster_membership_id = "" # required for private cluster, defaults to `cluster_name`

#######################################################
####    APPLICATIONS
#######################################################

## JupyterHub variables
namespace                                   = "ml"
gcs_bucket                                  = "gcs-bucket-dsfhfh"
create_gcs_bucket                           = true
workload_identity_service_account           = "jupyter-service-account"

# Jupyterhub with IAP
add_auth                  = false
# TODO make this a bool flag and fetch the project number in tf
brand                     = "projects/<prj-number>/brands/<prj-number>" # ensure brand is Internal
support_email             = "<email>"
k8s_ingress_name          = "jupyter-ingress"
k8s_managed_cert_name     = "jupyter-managed-cert"
k8s_iap_secret_name       = "jupyter-iap-secret"
k8s_backend_config_name   = "jupyter-iap-config"
k8s_backend_service_name  = "proxy-public"
k8s_backend_service_port  = 80

url_domain_addr           = ""
url_domain_name           = ""
client_id                 = ""
client_secret             = ""
members_allowlist         = ["allAuthenticatedUsers", "user:<email>"]
