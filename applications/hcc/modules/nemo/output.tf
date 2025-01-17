output "host_debug" {
  value                   = "https://${data.google_container_cluster.gke_cluster.endpoint}"
}

output "token_debug" {
  value                  = data.google_client_config.default.access_token
}

output "ca_debug" {
  value = base64decode(data.google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate)
}
