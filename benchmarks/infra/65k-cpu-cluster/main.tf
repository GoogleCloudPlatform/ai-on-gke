data "google_project" "project" {
  project_id = var.project_name
}

data "google_compute_network" "vpc" {
  name = var.vpc_network
}

resource "google_compute_subnetwork" "vpc" {
  name          = "${var.cluster_name}-vpc-subnet"
  ip_cidr_range = var.ip_cidr_range
  region        = var.region
  network       = data.google_compute_network.vpc.id

  depends_on = [data.google_compute_network.vpc]
}

resource "google_compute_router" "router" {
  name    = "nat-router-${var.cluster_name}"
  region  = var.region
  network = data.google_compute_network.vpc.id

  depends_on = [google_compute_subnetwork.vpc]
}

resource "google_compute_router_nat" "nat" {
  name                               = "nat-router-${var.cluster_name}"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
  min_ports_per_vm                   = 64

  depends_on = [google_compute_router.router]
}

resource "google_container_cluster" "test_cluster" {
  name                      = var.cluster_name
  location                  = var.region
  min_master_version        = var.min_master_version
  node_locations            = var.node_locations
  initial_node_count        = var.initial_node_count
  default_max_pods_per_node = 16

  release_channel {
    channel = "RAPID"
  }
  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 20
    disk_type    = "pd-standard"
    labels = {
      worker-node-pool = "true"
    }
  }

  # Do not block on destroy attempts.
  deletion_protection = false

  # Networking-related options.
  network           = data.google_compute_network.vpc.id
  subnetwork        = google_compute_subnetwork.vpc.id
  networking_mode   = "VPC_NATIVE"
  datapath_provider = var.datapath_provider

  private_cluster_config {
    enable_private_nodes   = true
    master_ipv4_cidr_block = var.master_ipv4_cidr_block
  }
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = var.cluster_ipv4_cidr_block
    services_ipv4_cidr_block = var.services_ipv4_cidr_block
  }

  workload_identity_config {
    workload_pool = "${data.google_project.project.project_id}.svc.id.goog"
  }

  # Miscellaneous other configuration options.
  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "APISERVER",
      "SCHEDULER",
      "CONTROLLER_MANAGER"
    ]
  }
  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "APISERVER",
      "SCHEDULER",
      "CONTROLLER_MANAGER"
    ]
  }

  depends_on = [google_compute_subnetwork.vpc]
}

locals {
  node_pool_parameters = {
    for i in range(var.node_pool_count) : format("pool%02d", i + 1) => var.node_pool_size
  }
}

resource "google_container_node_pool" "heapster-pool" {
  cluster    = google_container_cluster.test_cluster.id
  name       = "heapster-pool"
  node_count = 4
  node_config {
    machine_type = "n1-standard-64"
  }

  timeouts {
    create = var.node_pool_create_timeout
  }
}

resource "google_container_node_pool" "additional_pools" {
  for_each = local.node_pool_parameters

  cluster    = google_container_cluster.test_cluster.id
  name       = each.key
  node_count = each.value
  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 20
    disk_type    = "pd-standard"
    labels = {
      worker-node-pool = "true"
    }
  }
}