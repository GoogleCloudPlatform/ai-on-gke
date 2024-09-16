resource "google_compute_network" "vpc" {
  count = var.network_name != null ? 0 : 1

  auto_create_subnetworks = false
  name                    = local.network_name
  project                 = google_project_service.compute_googleapis_com.project
  routing_mode            = var.dynamic_routing_mode
}

data "google_compute_network" "vpc" {
  depends_on = [google_compute_network.vpc]

  name    = local.network_name
  project = data.google_project.environment.project_id
}

resource "google_compute_subnetwork" "region" {
  count = var.subnetwork_name != null ? 0 : 1

  ip_cidr_range            = var.subnet_cidr_range
  name                     = local.subnetwork_name
  network                  = data.google_compute_network.vpc.id
  private_ip_google_access = true
  project                  = google_project_service.compute_googleapis_com.project
  region                   = var.region
}

data "google_compute_subnetwork" "region" {
  depends_on = [google_compute_subnetwork.region]

  name    = local.subnetwork_name
  project = data.google_project.environment.project_id
  region  = var.region
}


resource "google_compute_router" "router" {
  name    = "router"
  network = local.network_name
  project = data.google_project.environment.project_id
  region  = var.region
}

resource "google_compute_router_nat" "nat_gateway" {
  name                               = "nat-gateway"
  nat_ip_allocate_option             = "AUTO_ONLY"
  project                            = data.google_project.environment.project_id
  region                             = var.region
  router                             = google_compute_router.router.name
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
