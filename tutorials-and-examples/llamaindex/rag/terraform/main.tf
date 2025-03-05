terraform {

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.19.0"
    }
  }
}
data "google_client_config" "default" {}


data "google_project" "project" {
  project_id = var.project_id
}


locals {
  cluster_name = var.cluster_name != "" ? var.cluster_name : var.default_resource_name
}

module "gke_cluster" {
  source = "../../../../infrastructure"

  project_id        = var.project_id
  cluster_name      = local.cluster_name
  cluster_location  = var.cluster_location
  autopilot_cluster = var.autopilot_cluster
  private_cluster   = var.private_cluster
  create_network    = false
  network_name      = "default"
  subnetwork_name   = "default"
  enable_gpu        = true
  gpu_pools = [
    {
      name               = "gpu-pool-l4"
      machine_type       = "g2-standard-24"
      node_locations     = "us-central1-a" ## comment to autofill node_location based on cluster_location
      autoscaling        = true
      min_count          = 1
      max_count          = 3
      disk_size_gb       = 100
      disk_type          = "pd-balanced"
      enable_gcfs        = true
      logging_variant    = "DEFAULT"
      accelerator_count  = 2
      accelerator_type   = "nvidia-l4"
      gpu_driver_version = "DEFAULT"
    }
  ]
  ray_addon_enabled = false
}

locals {
  #ca_certificate        = base64decode(module.gke_cluster.ca_certificate)
  cluster_membership_id = var.cluster_membership_id == "" ? local.cluster_name : var.cluster_membership_id
  host                  = var.private_cluster ? "https://connectgateway.googleapis.com/v1/projects/${data.google_project.project.number}/locations/${var.cluster_location}/gkeMemberships/${local.cluster_membership_id}" : "https://${module.gke_cluster.endpoint}"

}

provider "kubernetes" {
  alias                  = "llamaindex"
  host                   = local.host
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = var.private_cluster ? "" : base64decode(module.gke_cluster.ca_certificate)

  dynamic "exec" {
    for_each = var.private_cluster ? [1] : []
    content {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
}

locals {
  bucket_name          = var.bucket_name != "" ? var.bucket_name : var.default_resource_name
  service_account_name = var.service_account_name != "" ? var.service_account_name : var.default_resource_name
}


resource "google_storage_bucket" "bucket" {
  project = var.project_id
  name    = local.bucket_name

  location      = "US"
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
  force_destroy               = true
}

module "llamaindex_workload_identity" {
  providers = {
    kubernetes = kubernetes.llamaindex
  }
  source     = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  name       = local.service_account_name
  namespace  = "default"
  roles      = ["roles/storage.objectUser"]
  project_id = var.project_id
  depends_on = [module.gke_cluster]
}

locals {
  image_repository_name = var.image_repository_name != "" ? var.image_repository_name : var.default_resource_name
}

resource "google_artifact_registry_repository" "image_repo" {
  project       = var.project_id
  location      = "us"
  repository_id = local.image_repository_name
  format        = "DOCKER"
}

resource "google_artifact_registry_repository_iam_binding" "repo_binding" {
  project    = var.project_id
  location   = "us"
  repository = local.image_repository_name
  role       = "roles/artifactregistry.reader"
  members = [
    "serviceAccount:${module.gke_cluster.service_account}",
  ]
  depends_on = [google_artifact_registry_repository.image_repo, module.gke_cluster]
}


provider "kubectl" {
  alias                  = "llamaindex"
  apply_retry_count      = 15
  host                   = local.host
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = var.private_cluster ? "" : base64decode(module.gke_cluster.ca_certificate)
  load_config_file       = true

  dynamic "exec" {
    for_each = var.private_cluster ? [1] : []
    content {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
}


resource "local_file" "ollama-deployment-file" {
  content = templatefile(
    "${path.module}/../templates/ollama-deployment.yaml",
    {
      SERVICE_ACCOUNT_NAME = local.service_account_name,
      GCSFUSE_BUCKET_NAME  = local.bucket_name
    }
  )
  filename = "${path.module}/../gen/ollama-deployment.yaml"
}


resource "local_file" "ingest-data-job-file" {
  content = templatefile(
    "${path.module}/../templates/ingest-data-job.yaml",
    {
      IMAGE_NAME           = "us-docker.pkg.dev/${var.project_id}/${local.image_repository_name}/llamaindex-rag-demo:latest"
      SERVICE_ACCOUNT_NAME = local.service_account_name,
      GCSFUSE_BUCKET_NAME  = local.bucket_name
    }
  )
  filename = "${path.module}/../gen/ingest-data-job.yaml"
}

resource "local_file" "rag-deployment-file" {
  content = templatefile(
    "${path.module}/../templates/rag-deployment.yaml",
    {
      IMAGE_NAME = "us-docker.pkg.dev/${var.project_id}/${local.image_repository_name}/llamaindex-rag-demo:latest"
      MODEL_NAME = "gemma2:9b"
    }
  )
  filename = "${path.module}/../gen/rag-deployment.yaml"
}
