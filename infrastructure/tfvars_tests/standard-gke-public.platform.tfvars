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
# create_network    = true
# network_name      = "ml-network"
# ubnetwork_name   = "ml-subnet1"
# subnetwork_cidr   = "10.100.0.0/16"
# subnetwork_region = "us-central1"

create_network    = true
network_name      = "default"
subnetwork_name   = "default"
subnetwork_region = "us-east4"

## gke variables
private_cluster     = false ## Default true. Use false for a public cluster
autopilot_cluster   = false # false = standard cluster, true = autopilot cluster
cluster_name        = "test-cluster"
cluster_location    = "us-east4"
gcs_fuse_csi_driver = true
ray_addon_enabled   = true

cpu_pools = [{
  name         = "cpu-pool"
  machine_type = "n1-standard-16"
  autoscaling  = true
  min_count    = 1
  max_count    = 3
  disk_size_gb = 100
  disk_type    = "pd-standard"
}]

## make sure required gpu quotas are available in the corresponding region
enable_gpu = true
gpu_pools = [{
  name           = "gpu-pool-l4"
  machine_type   = "g2-standard-24"
  node_locations = "us-east4-c"
  autoscaling    = true

  min_count          = 2
  max_count          = 3
  accelerator_count  = 2
  disk_size_gb       = 200
  enable_gcfs        = true
  logging_variant    = "DEFAULT"
  disk_type          = "pd-balanced"
  accelerator_type   = "nvidia-l4"
  gpu_driver_version = "LATEST"
}]
