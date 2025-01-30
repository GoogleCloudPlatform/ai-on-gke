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


project_id             = "skypilot_project"
create_cluster         = true
cluster_name           = "skypilot-test"
cluster_location       = "us-central1"
enable_gpu             = true
create_service_account = false
create_brand           = false
create_gcs_bucket      = true
gcs_bucket             = "skypilot-model-bucket"

# For Autopilot clusters
autopilot_cluster = true

#  For Standard clusters, configure GPU node pools:
#autopilot_cluster = false

#  If using Standard cluster please uncomment the
#  following gpu_pools block to enable queued_provisioning
#  on the node pool
# gpu_pools = [{
# name = "gpu-pool"
# queued_provisioning = true
# machine_type = "g2-standard-24"
# disk_type = "pd-balanced"
# autoscaling = true
# min_count = 0
# max_count = 3
# initial_node_count = 0
# }]
