/**
 * Copyright 2024 Google LLC
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

output "created_resources" {
  description = "IDs of the resources created, if any."
  value       = module.gke-infra.created_resources
}

output "project_id" {
  description = "Project ID of where the GKE cluster is hosted"
  value       = module.gke-infra.project_id
}

output "fleet_host" {
  description = "Fleet Connect Gateway host that can be used to configure the GKE provider."
  value       = module.gke-infra.fleet_host
}

output "get_credentials" {
  description = "Run one of these commands to get cluster credentials. Credentials via fleet allow reaching private clusters without no direct connectivity."
  value       = module.gke-infra.get_credentials
}
