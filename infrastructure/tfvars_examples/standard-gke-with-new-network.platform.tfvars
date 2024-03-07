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
create_network    = true
network_name      = "demo-network-2"
subnetwork_name   = "demo-subnet-02"
subnetwork_cidr   = "10.100.0.0/16"
subnetwork_region = "us-central1"

## gke variables
private_cluster   = false ## Default true. Use false for a public cluster
autopilot_cluster = false # false = standard cluster, true = autopilot cluster
cluster_name      = "demo-cluster-1"
cluster_location  = "us-central1-a"

cpu_pools = [{
  name         = "cpu-pool"
  machine_type = "n1-standard-16"
  autoscaling  = true
  min_count    = 1
  max_count    = 3
  disk_size_gb = 100
  disk_type    = "pd-standard"
}]

## make sure required gpu quotas are available in that region
enable_gpu = true
gpu_pools = [{
  name               = "gpu-pool"
  machine_type       = "n1-standard-16"
  autoscaling        = true
  min_count          = 1
  max_count          = 3
  disk_size_gb       = 100
  disk_type          = "pd-standard"
  accelerator_count  = 2
  accelerator_type   = "nvidia-tesla-t4"
  gpu_driver_version = "DEFAULT"
}]
