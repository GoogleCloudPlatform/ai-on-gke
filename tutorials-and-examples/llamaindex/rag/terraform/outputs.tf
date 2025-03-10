
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

output "bucket_name" {
  value = local.bucket_name
}

output "demo_app_image_repo_name" {
  value = local.image_repository_name
}
