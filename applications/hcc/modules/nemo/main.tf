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

resource "helm_release" "nemo" {
  name      = "nemo"
  provider  = helm
  version     = "0.7.0"
  chart     = "${path.module}/helm-charts/nemo-training/"
  namespace = "default"
  reset_values = true
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
    value = "us-central1-docker.pkg.dev/deeplearning-images/reproducibility/pytorch-gpu-nemo@sha256:7a84264e71f82f225be639dd20fcf9104c80936c0f4f38f94b88dfb60303c70e"
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
