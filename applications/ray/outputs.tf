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
