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

project_id = "yiyingzhang-gke-dev"

## this is required for terraform to connect to GKE master and deploy workloads
create_cluster    = true # Create a GKE cluster in the specified network.
autopilot_cluster = true
cluster_name      = "test-refactor-rag2"
cluster_location  = "us-central1"
create_network    = true
network_name      = "ml-network"
subnetwork_cidr   = "10.100.0.0/16"

## GKE environment variables
kubernetes_namespace = "rag"
create_gcs_bucket    = true

# The bucket name must be globally unique (across all of Google Cloud).
# To verify, check that `gcloud storage buckets describe gs://<bucketname>` returns a 404.
gcs_bucket = "rag-data-yyz1"

cloudsql_instance        = "pgvector-instance"
cloudsql_instance_region = "us-central1" # defaults to cluster_location, if not specified

## Service accounts

# Creates a google service account & k8s service account & configures workload identity with appropriate permissions.
# Set to false & update the variable `ray_service_account` to use an existing IAM service account.
create_ray_service_account      = true
ray_service_account             = "ray-sa"
enable_grafana_on_ray_dashboard = false

# Creates a google service account & k8s service account & configures workload identity with appropriate permissions.
# Set to false & update the variable `rag_service_account` to use an existing IAM service account.
create_rag_service_account = true
rag_service_account        = "rag-sa"

# Creates a google service account & k8s service account & configures workload identity with appropriate permissions.
# Set to false & update the variable `jupyter_service_account` to use an existing IAM service account.
jupyter_service_account = "jupyter-sa"

## Embeddings table name - change this to the TABLE_NAME used in the notebook.
dataset_embeddings_table_name = "googlemaps_reviews_db"

## IAP config - if you choose to disable IAP authenticated access for your endpoints, ignore everthing below this line.
create_brand  = false
support_email = "<email>" ## specify if create_brand=true

## Jupyter IAP Settings
jupyter_add_auth                 = false # Set to true when using auth with IAP
jupyter_k8s_ingress_name         = "jupyter-ingress"
jupyter_k8s_managed_cert_name    = "jupyter-managed-cert"
jupyter_k8s_iap_secret_name      = "jupyter-iap-secret"
jupyter_k8s_backend_config_name  = "jupyter-iap-config"
jupyter_k8s_backend_service_name = "proxy-public"
jupyter_k8s_backend_service_port = 80

jupyter_domain            = "" ## Provide domain for ingress resource and ssl certificate. If it's empty, it will use nip.io wildcard dns
jupyter_client_id         = ""
jupyter_client_secret     = ""
jupyter_members_allowlist = "user:<email>,group:<email>,serviceAccount:<email>,domain:google.com"

## Frontend IAP Settings
frontend_add_auth                 = false # Set to true when using auth with IAP
frontend_k8s_ingress_name         = "frontend-ingress"
frontend_k8s_managed_cert_name    = "frontend-managed-cert"
frontend_k8s_iap_secret_name      = "frontend-iap-secret"
frontend_k8s_backend_config_name  = "frontend-iap-config"
frontend_k8s_backend_service_name = "rag-frontend"
frontend_k8s_backend_service_port = 8080

frontend_domain            = "" ## Provide domain for ingress resource and ssl certificate. If it's empty, it will use nip.io wildcard dns
frontend_client_id         = ""
frontend_client_secret     = ""
frontend_members_allowlist = "user:<email>,group:<email>,serviceAccount:<email>,domain:google.com"

## Ray Dashboard IAP Settings
ray_dashboard_add_auth                 = false # Set to true when using auth with IAP
ray_dashboard_k8s_ingress_name         = "ray-dashboard-ingress"
ray_dashboard_k8s_managed_cert_name    = "ray-dashboard-managed-cert"
ray_dashboard_k8s_iap_secret_name      = "ray-dashboard-iap-secret"
ray_dashboard_k8s_backend_config_name  = "ray-dashboard-iap-config"
ray_dashboard_k8s_backend_service_port = 8265

ray_dashboard_domain            = "" ## Provide domain for ingress resource and ssl certificate. If it's empty, it will use nip.io wildcard dns
ray_dashboard_client_id         = ""
ray_dashboard_client_secret     = ""
ray_dashboard_members_allowlist = "user:<email>,group:<email>,serviceAccount:<email>,domain:google.com"