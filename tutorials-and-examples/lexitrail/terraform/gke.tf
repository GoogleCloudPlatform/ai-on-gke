resource "google_container_cluster" "autopilot_cluster" {
  name             = local.cluster_name
  location         = var.region
  project          = local.project_id
  enable_autopilot = true
  deletion_protection = false
  
  # network section start
  network          = google_compute_network.main.name
  subnetwork       = google_compute_subnetwork.main.name
  ip_allocation_policy {}
  node_pool_auto_config {
    network_tags {
      tags = ["game-server"]
    }
  }
  # network section end
}

data "google_container_cluster" "cluster" {
  name     = google_container_cluster.autopilot_cluster.name
  location = google_container_cluster.autopilot_cluster.location
  project  = google_container_cluster.autopilot_cluster.project
}