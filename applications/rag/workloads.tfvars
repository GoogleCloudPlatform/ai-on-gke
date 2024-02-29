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

project_id = "<your project ID>"

## this is required for terraform to connect to GKE master and deploy workloads
create_cluster   = false # this flag will create a new standard public gke cluster in default network
cluster_name     = "<cluster_name>"
cluster_location = "us-central1"

## GKE environment variables
kubernetes_namespace = "rag"
create_gcs_bucket    = true
gcs_bucket           = "rag-data-xyzu" # Choose a globally unique bucket name.

## Service accounts
# Creates a google service account & k8s service account & configures workload identity with appropriate permissions.
# Set to false & update the variable `ray_service_account` to use an existing IAM service account.
create_ray_service_account      = true
ray_service_account             = "ray-system-account"
enable_grafana_on_ray_dashboard = false
# Creates a google service account & k8s service account & configures workload identity with appropriate permissions.
# Set to false & update the variable `rag_service_account` to use an existing IAM service account.
create_rag_service_account = true
rag_service_account        = "rag-system-account"

# Creates a google service account & k8s service account & configures workload identity with appropriate permissions.
# Set to false & update the variable `jupyter_service_account` to use an existing IAM service account.
create_jupyter_service_account = true
jupyter_service_account        = "jupyter-system-account"

## Embeddings table name - change this to the TABLE_NAME used in the notebook.
dataset_embeddings_table_name = "googlemaps_reviews_db"

## IAP config
add_auth                = false # Set to true when using auth with IAP
brand                   = "projects/<prj-number>/brands/<prj-number>"
support_email           = "<email>"
k8s_ingress_name          = "jupyter-ingress"
k8s_backend_config_name   = "jupyter-iap-config"
k8s_backend_service_name  = "proxy-public"

url_domain_addr   = ""
url_domain_name   = ""
client_id         = ""
client_secret     = ""
members_allowlist = ["allAuthenticatedUsers", "user:<email>"]
