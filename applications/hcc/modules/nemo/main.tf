locals {
  cluster_id_parts = split("/", var.cluster_id)
  cluster_name     = local.cluster_id_parts[5]
  cluster_location = local.cluster_id_parts[3]
  project_id       = local.cluster_id_parts[1]
  machine_type     = var.gpu_type == "A3 Mega" ? "a3mega" : var.gpu_type == "A3 Ultra" ? "a3ultra" : error("Only A3 Mega and A3 Ultra are supported") 
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

resource "helm_release" "benchmark" {
  count     = var.recipe == "gke-nccl" ? 0 : 1
  name      = "benchmark"
  provider  = helm
  version     = "0.7.0"
  chart     = "${path.module}/helm-charts/training/${local.machine_type}/${local.model_type}"
  namespace = "default"
  reset_values = true
  values = [
    "${file("${path.module}/${local.machine_type}/${local.model_type}/${local.values_file}")}"
  ]

  set {
    name  = "nemo_config"
    value = "${file("${path.module}/${local.machine_type}/${local.model_type}/${local.nccl_config}")}"
  }

  set {
    name  = "maxtext_config"
    value = "${file("${path.module}/${local.machine_type}/${local.model_type}/${local.nccl_config}")}"
  }

  set {
    name = "workload.gcsBucketForDataCataPath"
    value = var.checkpoint_bucket
  }

  set {
    name = "volumes.gcsMounts[0].bucketName"
    value = var.checkpoint_bucket
  }

  set {
    name = "queue"
    value = var.queue
  }

  set {
    name = "workload.gpus"
    value = var.node_count * 8
  }
}

resource "helm_release" "nccl_tests" {
  count     = var.recipe == "gke-nccl" ? 1 : 0
  name      = "nccl-tests"
  provider  = helm
  version   = "0.1.0"
  chart     = "${path.module}/helm-charts/nccl-tests/"
  namespace = "default"
  reset_values = true
  set {
    name = "workload.gcsBucketForDataCataPath"
    value = var.checkpoint_bucket
  }

  set {
    name = "workload.gpuType"
    value = var.gpu_type
  }

  set {
    name = "workload.node_count"
    value = var.node_count
  }

  set {
    name = "queue"
    value = var.queue
  }
}
