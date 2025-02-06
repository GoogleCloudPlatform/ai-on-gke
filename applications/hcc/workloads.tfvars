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

authorized_cidr = "0.0.0.0/0"

goog_cm_deployment_name = "a3ultra-qss-test-danjuan-3"

labels = {
  ghpc_blueprint  = "gke-a3-ultra"
  ghpc_deployment = "a3ultra-qss-test-danjuan-3"
}

project_id = "supercomputer-testing"

#a3_mega_zone = "us-east5-a"
a3_mega_zone = ""
a3_ultra_zone = "europe-west1-b"

#checkpoint_bucket = "kevinmcw-llama-checkpoint"
node_count = 2
recipe = "gke-nccl"

reservation = "supercomputer-testing-gsc-asq-fr/reservationBlocks/supercomputer-testing-gsc-asq-fr-block-0001"
reservation_block = ""
placement_policy_name = ""
host_maintenance = ""

a3ultra_node_pool_disk_size_gb = 100
system_node_pool_disk_size_gb = 200

mglru_disable_path = "mglru-disable.yaml"
nccl_installer_path = "nccl-installer.yaml"
