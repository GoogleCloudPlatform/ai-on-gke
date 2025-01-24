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

goog_cm_deployment_name = "a3plus-qss-test"

labels = {
  ghpc_blueprint  = "gke-a3-mega"
  ghpc_deployment = "a3plus-qss-test"
}

project_id = "supercomputer-testing"

region = "us-east5"

zone = "us-east5-a"

checkpoint_bucket = "kevinmcw-llama-checkpoint"
node_count = 2
recipe = "llama3.1_7b_nemo_pretraining"

reservation = "qss-test-a3mega"
reservation_block = ""
placement_policy_name = ""
