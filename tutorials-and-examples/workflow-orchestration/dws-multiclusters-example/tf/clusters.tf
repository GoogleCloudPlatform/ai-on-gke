provider "google" {
  project = var.project_id
}
# Create network and subnets for each region
resource "google_compute_network" "network" {
  name                    = "dws-network"
  auto_create_subnetworks = true

}


resource "google_container_cluster" "autopilot_manager_cluster" {


  name     = "${var.cluster_manager_name_prefix}-${var.location_manager}"
  location = var.location_manager
  network  = google_compute_network.network.id

  enable_autopilot    = true
  deletion_protection = false

}
# Create GKE Autopilot worker clusters
resource "google_container_cluster" "autopilot_worker_clusters" {
  for_each = {
    for region in var.regions_workers : region => {
      region = region
      name   = "${var.cluster_worker_names_prefix}-${region}" # Use prefix and region
    }
  }

  name                = each.value.name
  location            = each.value.region
  network             = google_compute_network.network.id # Reference the SINGLE network
  enable_autopilot    = true
  deletion_protection = false

}

# Get the kubeconfig for each cluster and update the context
resource "null_resource" "update_kubeconfig" {
  for_each = google_container_cluster.autopilot_worker_clusters

  provisioner "local-exec" {
    command = <<EOT
      gcloud container clusters get-credentials ${each.value.name} --region ${each.value.location} --project ${var.project_id}
      kubectl config rename-context gke_${var.project_id}_${each.value.location}_${each.value.name} ${each.value.name}

    EOT
  }

  depends_on = [google_container_cluster.autopilot_worker_clusters] # Ensure clusters are created first
}


# MultiKueue Manager Kubeconfig Update (Separate)
resource "null_resource" "update_manager_kubeconfig" {
  provisioner "local-exec" {
    command = <<EOT
      gcloud container clusters get-credentials ${google_container_cluster.autopilot_manager_cluster.name} --region ${google_container_cluster.autopilot_manager_cluster.location} --project ${var.project_id}
      kubectl config rename-context gke_${var.project_id}_${google_container_cluster.autopilot_manager_cluster.location}_${google_container_cluster.autopilot_manager_cluster.name} ${google_container_cluster.autopilot_manager_cluster.name}

    EOT
  }
  depends_on = [google_container_cluster.autopilot_manager_cluster]
}

