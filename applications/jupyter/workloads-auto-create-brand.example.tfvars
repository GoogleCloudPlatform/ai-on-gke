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
cluster_name     = "<cluster-name>"
cluster_location = "us-central1"
cluster_membership_id = "" # required only for private cluster, default: cluster_name

#######################################################
####    APPLICATIONS
#######################################################

## JupyterHub variables
namespace = "jupyter"
gcs_bucket = "<gcs-bucket>"
k8s_service_account = "default"
gcp_service_account ="jupyter-service-account"
gcp_service_account_iam_roles = "roles/storage.admin,roles/artifactregistry.reader"

# Jupyterhub with IAP
add_auth = true
brand = ""
support_email = "<email>"
default_backend_service = "proxy-public"
service_name = "iap-config-default"

url_domain_addr = ""
url_domain_name = ""
client_id = ""
client_secret = ""
members_allowlist = "allAuthenticatedUsers"
