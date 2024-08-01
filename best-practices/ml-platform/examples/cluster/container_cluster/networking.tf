data "google_compute_network" "vpc" {
  name    = local.network_name
  project = data.google_project.environment.project_id
}

data "google_compute_subnetwork" "region" {
  name    = local.subnetwork_name
  project = data.google_project.environment.project_id
  region  = var.region
}
