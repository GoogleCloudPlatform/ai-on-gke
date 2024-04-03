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

output "jupyterhub_uri" {
  description = "JupyterHub Endpoint to access user interface. In case of private IP, consider port-forwarding."
  value       = module.jupyterhub.jupyterhub_uri != "" ? "http://${module.jupyterhub.jupyterhub_uri}" : local.jupyterhub_default_uri
}

output "jupyterhub_ip_address" {
  description = "JupyterHub global IP address"
  value       = module.jupyterhub.jupyterhub_ip_address
}

output "jupyterhub_user" {
  description = "JupyterHub user is only required for standard authentication. Ignore, in case of IAP authentication"
  value       = module.jupyterhub.jupyterhub_user
}

output "jupyterhub_password" {
  description = "JupyterHub password is only required for standard authentication. Ignore, in case of IAP authentication"
  value       = module.jupyterhub.jupyterhub_password
  sensitive   = true
}

output "frontend_uri" {
  description = "RAG Frontend Endpoint to access user interface. In case of private IP, consider port-forwarding."
  value       = module.frontend.frontend_uri != "" ? "http://${module.frontend.frontend_uri}" : local.frontend_default_uri
}

output "frontend_ip_address" {
  description = "Frontend global IP address"
  value       = module.frontend.frontend_ip_address
}

output "ray_dashboard_uri" {
  description = "Ray Dashboard Endpoint to access user interface. In case of private IP, consider port-forwarding."
  value       = module.kuberay-cluster.ray_dashboard_uri != "" ? "http://${module.kuberay-cluster.ray_dashboard_uri}" : ""
}

output "ray_dashboard_ip_address" {
  description = "Ray Dashboard global IP address"
  value       = module.kuberay-cluster.ray_dashboard_ip_address
}

output "kubernetes_namespace" {
  value       = local.kubernetes_namespace
  description = "Kubernetes namespace"
}

output "gke_cluster_name" {
  value       = local.cluster_name
  description = "GKE cluster name"
}

output "gke_cluster_location" {
  value       = var.cluster_location
  description = "GKE cluster location"
}

output "project_id" {
  value       = var.project_id
  description = "GKE cluster location"
}

output "gcp_network" {
  value       = local.network_name
  description = "Provisioned GCP Network Name"
}
