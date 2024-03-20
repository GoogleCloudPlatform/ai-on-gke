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
project_id = "<project-id>"

#######################################################
####    PLATFORM
#######################################################
## network values
create_network  = true
network_name    = "ml-network"
subnetwork_name = "ml-subnet"

## required only in case new network provisioning
subnetwork_cidr           = "10.100.0.0/16"
subnetwork_region         = "us-central1"
subnetwork_private_access = "true"
subnetwork_description    = "GKE subnet"
network_secondary_ranges = {
  "ml-subnet" = [
    {
      range_name    = "us-central1-01-gke-01-pods-1"
      ip_cidr_range = "192.168.0.0/20"
    },
    {
      range_name    = "us-central1-01-gke-01-services-1"
      ip_cidr_range = "192.168.48.0/20"
    }
  ]
}

## gke variables
create_cluster                       = true
private_cluster                      = true ## Default true. Use false for a public cluster
autopilot_cluster                    = true # false = standard cluster, true = autopilot cluster
cluster_name                         = "ml-cluster"
kubernetes_version                   = "1.28"
cluster_location                     = "us-central1"
ip_range_pods                        = "us-central1-01-gke-01-pods-1"
ip_range_services                    = "us-central1-01-gke-01-services-1"
monitoring_enable_managed_prometheus = true
gcs_fuse_csi_driver                  = true ## enabled default for autopilot
deletion_protection                  = false
master_authorized_networks = [{
  cidr_block   = "10.100.0.0/16"
  display_name = "VPC"
}]

## Node configuration are ignored for autopilot clusters
cpu_pools = [{
  name                   = "cpu-pool"
  machine_type           = "n2-standard-8"
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
  },
  {
    name                   = "gpu-pool-l4"
    machine_type           = "g2-standard-24"
    node_locations         = "us-central1-b,us-central1-c"
    autoscaling            = true
    min_count              = 1
    max_count              = 3
    local_ssd_count        = 2
    spot                   = false
    disk_size_gb           = 100
    disk_type              = "pd-ssd"
    image_type             = "COS_CONTAINERD"
    enable_gcfs            = true
    enable_gvnic           = false
    logging_variant        = "DEFAULT"
    auto_repair            = true
    auto_upgrade           = true
    create_service_account = true
    preemptible            = false
    initial_node_count     = 1
    accelerator_count      = 2
    accelerator_type       = "nvidia-l4"
    gpu_driver_version     = "DEFAULT"
  }
]

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


cluster_labels = {
  "created-by" = "ai-on-gke"
}

all_node_pools_labels = {
  "created-by" = "ai-on-gke"
}

all_node_pools_metadata = {
  disable-legacy-endpoints = "true"
}

all_node_pools_tags = ["gke-node", "ai-on-gke"]

