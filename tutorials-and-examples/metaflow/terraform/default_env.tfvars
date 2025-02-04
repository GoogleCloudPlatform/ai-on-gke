# Copyright 2025 Google LLC
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

project_id            = "akvelon-gke-aieco"
default_resource_name = "metaflow-tutorial-tf"

cluster_name      = "" # Leave empty to use the default name (default_resource_name) 
cluster_location  = "us-central1"
private_cluster   = false
autopilot_cluster = true

network_name           = "" # Leave empty to use the default name
subnetwork_name        = "" # Leave empty to use the default name
subnetwork_region      = "us-central1"
subnetwork_cidr        = "10.128.0.0/20"
subnetwork_description = "Part of the Metaflow o GKE installation"


service_account_name  = "" # Leave empty to use the default name
bucket_name           = "" # Leave empty to use the default name
image_repository_name = "" # Leave empty to use the default name

metaflow_cloudsql_instance               = "" # Leave empty to use the default name
metaflow_cloudsql_instance_region        = "us-central1"
metaflow_kubernetes_namespace            = "default"
metaflow_kubernetes_service_account_name = "metaflow-tutorial-sa"

metaflow_argo_workflows_sa_name = "metaflow-tutorial-argo-sa"

