output "grafana_uri" {
  value = module.kuberay-monitoring[0].grafana_uri
}

output "ray_cluster_uri" {
  value = module.kuberay-cluster[0].ray_cluster_uri != "" ? "http://${module.kuberay-cluster[0].ray_cluster_uri}" : local.ray_cluster_default_uri
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