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
project_id = "ai-sandbox-5"

#######################################################
####    PLATFORM
#######################################################
## network values
create_network            = true
network_name              = "demo-network-4"
subnetwork_name           = "demo-subnet-04"
subnetwork_cidr           = "10.100.0.0/16"
subnetwork_region         = "us-central1"
subnetwork_private_access = "true"
subnetwork_description    = "GKE subnet"
network_secondary_ranges = {
  "demo-subnet-04" = [
    {
      range_name    = "us-central1-01-gke-01-pods-3"
      ip_cidr_range = "192.168.0.0/20"
    },
    {
      range_name    = "us-central1-01-gke-01-services-3"
      ip_cidr_range = "192.168.48.0/20"
    }
  ]
}

## gke variables
create_cluster                       = true
private_cluster                      = false
cluster_name                         = "demo-cluster-4"
kubernetes_version                   = "1.27"
cluster_regional                     = true
cluster_region                       = "us-central1"
cluster_zones                        = ["us-central1-a", "us-central1-b", "us-central1-f"]
ip_range_pods                        = "us-central1-01-gke-01-pods-3"     ## name should match with secondary ranges names
ip_range_services                    = "us-central1-01-gke-01-services-3" ## name should match with secondary ranges names
monitoring_enable_managed_prometheus = true
master_authorized_networks = [{
  cidr_block   = "122.169.15.5/32" ## public IPs should be configured, if authorized network is required
  display_name = "Home"
}]

cpu_pools = [{
  name                   = "cpu-pool"
  machine_type           = "n1-standard-16"
  node_locations         = "us-central1-b,us-central1-c"
  autoscaling            = true
  min_count              = 1
  max_count              = 3
  local_ssd_count        = 0
  spot                   = false
  disk_size_gb           = 100
  disk_type              = "pd-standard"
  image_type             = "COS_CONTAINERD"
  enable_gcfs            = false
  enable_gvnic           = false
  logging_variant        = "DEFAULT"
  auto_repair            = true
  auto_upgrade           = true
  create_service_account = true
  preemptible            = false
  initial_node_count     = 1
  accelerator_count      = 0
}]

## make sure gpu quotas are available in given region
enable_gpu = true
gpu_pools = [{
  name                   = "gpu-pool"
  machine_type           = "n1-standard-16"
  node_locations         = "us-central1-b,us-central1-c"
  autoscaling            = true
  min_count              = 1
  max_count              = 3
  local_ssd_count        = 0
  spot                   = false
  disk_size_gb           = 100
  disk_type              = "pd-standard"
  image_type             = "COS_CONTAINERD"
  enable_gcfs            = false
  enable_gvnic           = false
  logging_variant        = "DEFAULT"
  auto_repair            = true
  auto_upgrade           = true
  create_service_account = true
  preemptible            = false
  initial_node_count     = 1
  accelerator_count      = 2
  accelerator_type       = "nvidia-tesla-t4"
  gpu_driver_version     = "DEFAULT"
}]

enable_tpu = false
tpu_pools = [{
  name                   = "tpu-pool"
  machine_type           = "ct4p-hightpu-4t"
  node_locations         = "us-central1-b,us-central1-c"
  autoscaling            = true
  min_count              = 1
  max_count              = 3
  local_ssd_count        = 0
  spot                   = false
  disk_size_gb           = 100
  disk_type              = "pd-standard"
  image_type             = "COS_CONTAINERD"
  enable_gcfs            = false
  enable_gvnic           = false
  logging_variant        = "DEFAULT"
  auto_repair            = true
  auto_upgrade           = true
  create_service_account = true
  preemptible            = false
  initial_node_count     = 1
  accelerator_count      = 2
  accelerator_type       = "nvidia-tesla-t4"
}]


## pools config variables
all_node_pools_oauth_scopes = [
  "https://www.googleapis.com/auth/logging.write",
  "https://www.googleapis.com/auth/monitoring",
  "https://www.googleapis.com/auth/devstorage.read_only",
  "https://www.googleapis.com/auth/trace.append",
  "https://www.googleapis.com/auth/service.management.readonly",
  "https://www.googleapis.com/auth/servicecontrol",
]

all_node_pools_labels = {
  "gke-profile" = "ai-on-gke"
}

all_node_pools_metadata = {
  disable-legacy-endpoints = "true"
}

all_node_pools_tags = ["gke-node", "ai-on-gke"]


