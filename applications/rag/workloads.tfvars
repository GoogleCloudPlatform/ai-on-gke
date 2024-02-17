# Copyright 2024 Google LLC
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

project_id = "<project_id>"

## this is required for terraform to connect to GKE master and deploy workloads
cluster_name     = "<cluster_name>"
cluster_location = "us-central1"

## GKE environment variables
kubernetes_namespace      = "rag"
gcs_bucket                = "rag-data-xyzu" # Choose a globally unique bucket name.

## Service accounts
# Creates a google service account & k8s service account & configures workload identity with appropriate permissions.
# Set to false & update the variable `ray_service_account` to use an existing IAM service account.
create_ray_service_account = true
ray_service_account        = "ray-system-account"

# Creates a google service account & k8s service account & configures workload identity with appropriate permissions.
# Set to false & update the variable `rag_service_account` to use an existing IAM service account.
create_rag_service_account = true
rag_service_account        = "rag-system-account"

# Creates a google service account & k8s service account & configures workload identity with appropriate permissions.
# Set to false & update the variable `jupyter_service_account` to use an existing IAM service account.
create_jupyter_service_account  = true
jupyter_service_account = "jupyter-system-account"

# IAP config
add_auth                = false # Set to true when using auth with IAP
brand                   = "projects/<prj-number>/brands/<prj-number>"
support_email           = "<email>"
default_backend_service = "proxy-public"
service_name            = "iap-config-default"

url_domain_addr   = ""
url_domain_name   = ""
client_id         = ""
client_secret     = ""
members_allowlist = "allAuthenticatedUsers,user:<email>"
