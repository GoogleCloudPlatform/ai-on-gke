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

# output "instructions_gke_cluster" {
#   description = "Generated output from module 'gke_cluster'"
#   value       = module.gke_cluster.instructions
# }
# 
# output "instructions_a3_megagpu_pool" {
#   description = "Generated output from module 'a3_megagpu_pool'"
#   value       = module.a3_megagpu_pool.instructions
# }

output "debug_ca" {
  description = "Generated output from module 'a3_megagpu_pool'"
  value       = module.nemo.ca_debug
}
