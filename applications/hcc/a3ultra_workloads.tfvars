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

goog_cm_deployment_name = "a3ultra-qss-test"

labels = {
  ghpc_blueprint  = "gke-a3-ultra"
  ghpc_deployment = "a3ultra-qss-test"
}

project_id = "supercomputer-testing"

a3_mega_zone = ""
a3_ultra_zone = "europe-west1-b"

node_count_gke_nccl = 0
node_count_gke = 0
node_count_llama_3_70b = 32
node_count_llama_3_7b = 2

#recipe = "gke-nccl"
recipe = "llama3.1_7b_nemo_pretraining"

reservation = "supercomputer-testing-gsc-asq-fr/reservationBlocks/supercomputer-testing-gsc-asq-fr-block-0001"
reservation_block = ""
placement_policy_name = ""

gpu_type = "A3 Ultra"
