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

goog_cm_deployment_name = "a3mega-qss-test"

labels = {
  ghpc_blueprint  = "gke-a3-mega"
  ghpc_deployment = "a3mega-qss-test"
}

project_id = "supercomputer-testing"

a3_mega_zone = "australia-southeast1-c"
a3_ultra_zone = ""

gpu_type = "A3 Mega"

reservation = "hcc-a3mega"
reservation_block = ""
placement_policy_name = "kevinmcw-test"

recipe = "gke-nccl"
node_count_gke_nccl = 2
node_count_gke = 0
node_count_nemo = 16
node_count_maxtext = 16
node_count_llama_3_7b = 2
a3_mega_consumption_model = "Reservation"
a3_ultra_consumption_model = ""