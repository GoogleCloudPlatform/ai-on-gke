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
## Need to pull this variables from tf output from previous platform stage
project_id = "flyte_project"

## this is required for terraform to connect to GKE master and deploy workloads
create_cluster   = true # this flag will create a new standard public gke cluster in default network
cluster_name     = "flyte-test"
cluster_location = "us-central1"

autopilot_cluster = true
enable_gpu = true

create_gcs_bucket = true
gcs_bucket = "flyte-bucket"