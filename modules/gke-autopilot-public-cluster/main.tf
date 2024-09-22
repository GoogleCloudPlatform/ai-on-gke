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

module "gke" {
  source                     = "terraform-google-modules/kubernetes-engine/google//modules/beta-autopilot-public-cluster"
  version                    = "33.0.0"
  project_id                 = var.project_id
  regional                   = var.cluster_regional
  name                       = var.cluster_name
  cluster_resource_labels    = var.cluster_labels
  region                     = var.cluster_region
  kubernetes_version         = var.kubernetes_version
  release_channel            = var.release_channel
  zones                      = var.cluster_zones
  network                    = var.network_name
  subnetwork                 = var.subnetwork_name
  ip_range_pods              = var.ip_range_pods
  ip_range_services          = var.ip_range_services
  master_authorized_networks = var.master_authorized_networks
  deletion_protection        = var.deletion_protection

  ray_operator_config = {
    enabled            = var.ray_addon_enabled
    logging_enabled    = var.ray_addon_enabled
    monitoring_enabled = var.ray_addon_enabled
  }
}
