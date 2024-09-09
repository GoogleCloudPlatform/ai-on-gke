provider "google" {
  project = var.google-project
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.nim-llm.endpoint}"
  cluster_ca_certificate = base64decode(data.google_container_cluster.nim-llm.master_auth.0.cluster_ca_certificate)
  token                  = data.google_client_config.current.access_token
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.nim-llm.endpoint}"
    cluster_ca_certificate = base64decode(data.google_container_cluster.nim-llm.master_auth.0.cluster_ca_certificate)
    token                  = data.google_client_config.current.access_token
  }
}

