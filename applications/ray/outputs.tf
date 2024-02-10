output "ray_uri" {
  value = module.kuberay-cluster[0].ray_uri
}

output "grafana_uri" {
  value = module.kuberay-monitoring[0].grafana_uri
}
