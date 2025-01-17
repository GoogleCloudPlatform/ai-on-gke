locals {
  cluster_id_parts = split("/", var.cluster_id)
  cluster_name     = local.cluster_id_parts[5]
  cluster_location = local.cluster_id_parts[3]
  project_id       = local.cluster_id_parts[1]
}

data "google_client_config" "default" {}

data "google_project" "project" {
  project_id = local.project_id
}

data "google_container_cluster" "gke_cluster" {
  project  = local.project_id
  name     = local.cluster_name
  location = local.cluster_location
}

# provider "google" {
#   project = local.project_id
# }
# 
# provider "helm" {
#   kubernetes {
#     host                   = "https://${data.google_container_cluster.gke_cluster.endpoint}"
#     token                  = data.google_client_config.default.access_token
#     cluster_ca_certificate = base64decode(data.google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate)
#   }
# }

# provider "kubernetes" {
#     host                   = "https://${data.google_container_cluster.gke_cluster.endpoint}"
#     token                  = data.google_client_config.default.access_token
#     cluster_ca_certificate = base64decode(data.google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate)
# }


resource "helm_release" "nemo" {
  name      = "nemo"
  provider  = helm
  version     = "0.7.0"
  chart     = "${path.module}/helm-charts/nemo-training/"
  namespace = "default"
  reset_values = true
# Timeout is increased to guarantee sufficient scale-up time for Autopilot nodes.
  timeout    = 1200
  values = [
    "${file("${path.module}/values.yaml")}"
  ]

  set {
    name  = "nemo_config"
    value = "${file("${path.module}/llama3-70b-fp8.yaml")}"
  }
  
  set {
    name = "workload.image"
    # TODO: this needs to be a public image
    value = "us-west1-docker.pkg.dev/supercomputer-testing/kevinmcw-repo/nemo_workload:24.07"
  }
  
  set {
    name = "workload.gcsBucketForDataCataPath"
    value = var.checkpoint_bucket
  }

  set {
    name = "workload.gpus"
    value = var.gpus
  }
}
