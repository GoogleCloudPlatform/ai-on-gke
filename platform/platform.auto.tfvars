
##common variables
project_id = "umeshkumhar"

#######################################################
####    PLATFORM
#######################################################
## network values
create_network            = false
network_name              = "demo-network"
subnetwork_name           = "subnet-01"
subnetwork_cidr           = "10.100.0.0/16"
subnetwork_region         = "us-central1"
subnetwork_private_access = "true"
subnetwork_description    = "GKE subnet"
network_secondary_ranges = {
  subnet-01 = [
    {
      range_name    = "us-central1-01-gke-01-pods-1"
      ip_cidr_range = "192.168.0.0/20"
    },
    {
      range_name    = "us-central1-01-gke-01-services-1"
      ip_cidr_range = "192.168.48.0/20"
    }
  ]
}

## gke variables
create_cluster                       = false
private_cluster                      = false
cluster_name                         = "demo2"
kubernetes_version                   = "1.25"
cluster_regional                     = true
cluster_region                       = "us-central1"
cluster_zones                        = ["us-central1-a", "us-central1-b", "us-central1-f"]
ip_range_pods                        = "us-central1-01-gke-01-pods-1"
ip_range_services                    = "us-central1-01-gke-01-services-1"
monitoring_enable_managed_prometheus = true

cpu_pools = [{
  name                   = "cpu-pool"
  machine_type           = "n1-standard-16"
  node_locations         = "us-central1-b,us-central1-c"
  autoscaling            = true
  min_count              = 1
  max_count              = 3
  local_ssd_count        = 0
  spot                   = false
  disk_size_gb           = 100
  disk_type              = "pd-standard"
  image_type             = "COS_CONTAINERD"
  enable_gcfs            = false
  enable_gvnic           = false
  logging_variant        = "DEFAULT"
  auto_repair            = true
  auto_upgrade           = true
  create_service_account = true
  preemptible            = false
  initial_node_count     = 1
  accelerator_count      = 0
}]

enable_gpu = true
gpu_pools = [{
  name                   = "gpu-pool"
  machine_type           = "n1-standard-16"
  node_locations         = "us-central1-b,us-central1-c"
  autoscaling            = true
  min_count              = 1
  max_count              = 3
  local_ssd_count        = 0
  spot                   = false
  disk_size_gb           = 100
  disk_type              = "pd-standard"
  image_type             = "COS_CONTAINERD"
  enable_gcfs            = false
  enable_gvnic           = false
  logging_variant        = "DEFAULT"
  auto_repair            = true
  auto_upgrade           = true
  create_service_account = true
  preemptible            = false
  initial_node_count     = 1
  accelerator_count      = 2
  accelerator_type       = "nvidia-tesla-t4"
}]

enable_tpu = false
tpu_pools = [{
  name                   = "tpu-pool"
  machine_type           = "ct4p-hightpu-4t"
  node_locations         = "us-central1-b,us-central1-c"
  autoscaling            = true
  min_count              = 1
  max_count              = 3
  local_ssd_count        = 0
  spot                   = false
  disk_size_gb           = 100
  disk_type              = "pd-standard"
  image_type             = "COS_CONTAINERD"
  enable_gcfs            = false
  enable_gvnic           = false
  logging_variant        = "DEFAULT"
  auto_repair            = true
  auto_upgrade           = true
  create_service_account = true
  preemptible            = false
  initial_node_count     = 1
  accelerator_count      = 2
  accelerator_type       = "nvidia-tesla-t4"
}]


## pools config variables
all_node_pools_oauth_scopes = [
  "https://www.googleapis.com/auth/logging.write",
  "https://www.googleapis.com/auth/monitoring",
  "https://www.googleapis.com/auth/devstorage.read_only",
  "https://www.googleapis.com/auth/trace.append",
  "https://www.googleapis.com/auth/service.management.readonly",
  "https://www.googleapis.com/auth/servicecontrol",
]

all_node_pools_labels = {
  "cloud.google.com/gke-profile" = "ray"
}

all_node_pools_metadata = {
  disable-legacy-endpoints = "true"
}

all_node_pools_tags = ["gke-node", "ai-on-gke"]


