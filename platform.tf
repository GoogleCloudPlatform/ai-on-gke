#######################################################
####    PLATFORM
#######################################################

module "ai-on-gke" {
  count      = var.create_cluster ? 1 : 0
  source = "./modules/gke-standard-cluster"
  project_id = var.project_id

  ## network values
  create_network            = var.create_network
  network_name              = var.network_name
  subnetwork_name           = var.subnetwork_name
  subnetwork_cidr           = var.subnetwork_cidr
  subnetwork_region         = var.subnetwork_region
  subnetwork_private_access = var.subnetwork_private_access
  subnetwork_description    = var.subnetwork_description
  network_secondary_ranges  = var.network_secondary_ranges

  ## gke variables
  create_cluster                       = var.create_cluster
  cluster_name                         = var.cluster_name
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

