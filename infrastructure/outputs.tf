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

output "project_id" {
  value = var.project_id
}

output "cluster_name" {
  value = var.cluster_name
}

output "cluster_location" {
  value = var.cluster_location
}

output "endpoint" {
  value = var.create_cluster && var.autopilot_cluster && var.private_cluster ? module.private-gke-autopilot-cluster[0].endpoint : (
    var.create_cluster && !var.autopilot_cluster && var.private_cluster ? module.private-gke-standard-cluster[0].endpoint : (
      var.create_cluster && var.autopilot_cluster && !var.private_cluster ? module.public-gke-autopilot-cluster[0].endpoint : (
        var.create_cluster && !var.autopilot_cluster && !var.private_cluster ? module.public-gke-standard-cluster[0].endpoint :
  "")))
  sensitive  = true
  depends_on = [module.private-gke-autopilot-cluster, module.private-gke-standard-cluster, module.public-gke-autopilot-cluster, module.public-gke-standard-cluster]
}

output "ca_certificate" {
  value = var.create_cluster && var.autopilot_cluster && var.private_cluster ? module.private-gke-autopilot-cluster[0].ca_certificate : (
    var.create_cluster && !var.autopilot_cluster && var.private_cluster ? module.private-gke-standard-cluster[0].ca_certificate : (
      var.create_cluster && var.autopilot_cluster && !var.private_cluster ? module.public-gke-autopilot-cluster[0].ca_certificate : (
        var.create_cluster && !var.autopilot_cluster && !var.private_cluster ? module.public-gke-standard-cluster[0].ca_certificate :
  "")))
  sensitive  = true
  depends_on = [module.private-gke-autopilot-cluster, module.private-gke-standard-cluster, module.public-gke-autopilot-cluster, module.public-gke-standard-cluster]

}

output "service_account" {
  value = var.create_cluster && var.autopilot_cluster && var.private_cluster ? module.private-gke-autopilot-cluster[0].service_account : (
    var.create_cluster && !var.autopilot_cluster && var.private_cluster ? module.private-gke-standard-cluster[0].service_account : (
      var.create_cluster && var.autopilot_cluster && !var.private_cluster ? module.public-gke-autopilot-cluster[0].service_account : (
        var.create_cluster && !var.autopilot_cluster && !var.private_cluster ? module.public-gke-standard-cluster[0].service_account :
  "")))
  sensitive  = true
  depends_on = [module.private-gke-autopilot-cluster, module.private-gke-standard-cluster, module.public-gke-autopilot-cluster, module.public-gke-standard-cluster]

}

output "private_cluster" {
  value = var.private_cluster
}
