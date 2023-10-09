#######################################################
####    PLATFORM
#######################################################

## create VPC network & subnets
resource "google_compute_network" "custom-network" {
  count                   = var.create_network ? 1 : 0
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
}

module "vpc-subnets" {
  source       = "terraform-google-modules/network/google//modules/subnets"
  count        = var.create_network ? 1 : 0
  project_id   = var.project_id
  network_name = google_compute_network.custom-network[count.index].name
  subnets = [
    {
      subnet_name           = var.subnetwork_name
      subnet_ip             = var.subnetwork_cidr
      subnet_region         = var.subnetwork_region
      subnet_private_access = var.subnetwork_private_access
      description           = var.subnetwork_description
    }
  ]
  secondary_ranges = var.network_secondary_ranges
}

locals {
  network_name    = var.create_network ? google_compute_network.custom-network[0].name : var.network_name
  subnetwork_name = var.create_network ? module.vpc-subnets.subnets.0.name : var.subnetwork_name
}

## create public GKE
module "public-gke-standard-cluster" {
  count      = var.create_cluster && !var.private_cluster ? 1 : 0
  source     = "../modules/gke-standard-public-cluster"
  project_id = var.project_id

  ## network values
  network_name    = local.network_name
  subnetwork_name = local.subnetwork_name

  ## gke variables
  cluster_regional                     = var.cluster_regional
  cluster_name                         = var.cluster_name
  kubernetes_version                   = var.kubernetes_version
  cluster_region                       = var.cluster_region
  cluster_zones                        = var.cluster_zones
  ip_range_pods                        = var.ip_range_pods
  ip_range_services                    = var.ip_range_services
  monitoring_enable_managed_prometheus = var.monitoring_enable_managed_prometheus

  ## pools config variables
  cpu_pools                   = var.cpu_pools
  enable_gpu                  = var.enable_gpu
  gpu_pools                   = var.gpu_pools
  enable_tpu                  = var.enable_tpu
  tpu_pools                   = var.tpu_pools
  all_node_pools_oauth_scopes = var.all_node_pools_oauth_scopes
  all_node_pools_labels       = var.all_node_pools_labels
  all_node_pools_metadata     = var.all_node_pools_metadata
  all_node_pools_tags         = var.all_node_pools_tags
}

## create private GKE
module "private-gke-standard-cluster" {
  count      = var.create_cluster && var.private_cluster ? 1 : 0
  source     = "../modules/gke-standard-private-cluster"
  project_id = var.project_id

  ## network values
  network_name    = local.network_name
  subnetwork_name = local.subnetwork_name

  ## gke variables
  cluster_regional                     = var.cluster_regional
  cluster_name                         = var.cluster_name
  kubernetes_version                   = var.kubernetes_version
  cluster_region                       = var.cluster_region
  cluster_zones                        = var.cluster_zones
  ip_range_pods                        = var.ip_range_pods
  ip_range_services                    = var.ip_range_services
  monitoring_enable_managed_prometheus = var.monitoring_enable_managed_prometheus
  master_authorized_networks           = var.master_authorized_networks

  ## pools config variables
  cpu_pools                   = var.cpu_pools
  enable_gpu                  = var.enable_gpu
  gpu_pools                   = var.gpu_pools
  enable_tpu                  = var.enable_tpu
  tpu_pools                   = var.tpu_pools
  all_node_pools_oauth_scopes = var.all_node_pools_oauth_scopes
  all_node_pools_labels       = var.all_node_pools_labels
  all_node_pools_metadata     = var.all_node_pools_metadata
  all_node_pools_tags         = var.all_node_pools_tags
}

