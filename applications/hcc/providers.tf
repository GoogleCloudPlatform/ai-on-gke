/**
  * Copyright 2023 Google LLC
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
  * You may obtain a copy of the License at
  *
  *      http://www.apache.org/licenses/LICENSE-2.0
  *
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the License is distributed on an "AS IS" BASIS,
  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  * See the License for the specific language governing permissions and
  * limitations under the License.
  */

provider "google" {
  project = var.project_id
  region  = local.region
  zone    = local.zone
}

provider "google-beta" {
  project = var.project_id
  region  = local.region
  zone    = local.zone
}

provider "kubectl" {
  host                   = local.gke_cluster_endpoint
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(local.gke_cluster_ca_cert)
  load_config_file       = false
  apply_retry_count      = 15 # Terraform may apply resources in parallel, leading to potential dependency issues. This retry mechanism ensures that if a resource's dependencies aren't ready, Terraform will attempt to apply it again.
}

provider "kubernetes" {
  host                   = local.gke_cluster_endpoint
  cluster_ca_certificate = base64decode(local.gke_cluster_ca_cert)
  token                  = data.google_client_config.default.access_token
} 

provider "helm" {
  kubernetes {
    host                   = local.gke_cluster_endpoint
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(local.gke_cluster_ca_cert)
  }
}
