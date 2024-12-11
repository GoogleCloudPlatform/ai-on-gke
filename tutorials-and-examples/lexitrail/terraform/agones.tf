provider "helm" {
  kubernetes {
    host                   = data.google_container_cluster.cluster.endpoint
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.cluster.master_auth.0.cluster_ca_certificate)
  }
}

resource "helm_release" "agones" {
  name       = "agones"
  repository = "https://agones.dev/chart/stable"
  chart      = "agones"
  version    = "1.44.0"  # Use your desired Agones version
  namespace = "agones-system"
  create_namespace = true
  depends_on = [
    google_container_cluster.autopilot_cluster
  ]
}