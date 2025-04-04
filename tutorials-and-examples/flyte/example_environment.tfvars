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

project_id = "flyte_project"

## Cluster configuration
create_cluster   = true
cluster_name     = "flyte-test"
cluster_location = "us-central1"

autopilot_cluster = true
enable_gpu = true

# Network configuration
create_network = true
network_name = "flyte"
subnetwork_name = "flyte"

# GCS bucket configuration
create_gcs_bucket = true
gcs_bucket = "flyte-bucket"

# Database configuration
db_instance_name = "flytepg"
