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

resource "google_compute_network" "custom-network" {
  count                   = var.create_network ? 1 : 0
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
}

module "vpc" {
  source       = "terraform-google-modules/network/google//modules/subnets"
  count        = var.create_network ? 1 : 0
  project_id   = var.project_id
  network_name = google_compute_network.custom-network[count.index].name
  subnets = [
    {
      subnet_name           = var.subnetwork_name
      subnet_ip             = var.subnetwork_cidr
      subnet_region         = var.subnetwork_region
      subnet_private_access = var.subnetwork_private_access
      description           = var.subnetwork_description
    }
  ]
  secondary_ranges = var.network_secondary_ranges
}

locals {
  node_pools = concat((var.enable_gpu ? var.gpu_pools : []), (var.enable_tpu ? var.tpu_pools : []), var.cpu_pools)
}

module "gke" {
  count        = var.create_cluster ? 1 : 0
  source                               = "terraform-google-modules/kubernetes-engine/google"
  project_id                           = var.project_id
  name                                 = var.cluster_name
  region                               = var.cluster_region
  zones                                = var.cluster_zones
  network                              = var.network_name
  subnetwork                           = var.subnetwork_name
  ip_range_pods                        = var.ip_range_pods
  ip_range_services                    = var.ip_range_services
  remove_default_node_pool             = true
  logging_enabled_components           = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  monitoring_enabled_components        = ["SYSTEM_COMPONENTS"]
  monitoring_enable_managed_prometheus = var.monitoring_enable_managed_prometheus

  node_pools = local.node_pools

  node_pools_oauth_scopes = {
    all = var.all_node_pools_oauth_scopes
  }

  node_pools_labels = {
    all = var.all_node_pools_labels
  }

  node_pools_metadata = {
    all = var.all_node_pools_metadata
  }

  node_pools_tags = {
    all = var.all_node_pools_tags
  }
  depends_on = [google_compute_network.custom-network, module.vpc]
}
