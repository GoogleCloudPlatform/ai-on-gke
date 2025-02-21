/**
  * Copyright 2023 Google LLC
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
  * You may obtain a copy of the License at
  *
  *      http://www.apache.org/licenses/LICENSE-2.0
  *
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the License is distributed on an "AS IS" BASIS,
  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  * See the License for the specific language governing permissions and
  * limitations under the License.
  */

data "google_client_config" "default" {}

locals {
  subnetwork_name = "${var.goog_cm_deployment_name}-gke-net"
  result_bucket_name = "${var.project_id}-${var.goog_cm_deployment_name}-result"
  gke_cluster_id = var.gpu_type == "A3 Mega"? "${module.a3-megagpu-cluster[0].cluster_id}" : var.gpu_type == "A3 Ultra"? "${module.a3-ultragpu-cluster[0].cluster_id}" : error("Only A3 Mega and A3 Ultra are supported")
  gke_cluster_version = var.gpu_type == "A3 Mega"? "${module.a3-megagpu-cluster[0].gke_version}" : var.gpu_type == "A3 Ultra"? "${module.a3-ultragpu-cluster[0].gke_version}" : error("Only A3 Mega and A3 Ultra are supported")

  gke_cluster_endpoint = var.gpu_type == "A3 Mega"? "${module.a3-megagpu-cluster[0].gke_endpoint}" : var.gpu_type == "A3 Ultra"? "${module.a3-ultragpu-cluster[0].gke_endpoint}" : error("Only A3 Mega and A3 Ultra are supported")
  gke_cluster_ca_cert = var.gpu_type == "A3 Mega"? "${module.a3-megagpu-cluster[0].gke_ca_cert}" : var.gpu_type == "A3 Ultra"? "${module.a3-ultragpu-cluster[0].gke_ca_cert}" : error("Only A3 Mega and A3 Ultra are supported")
}

module "gke-a3-mega-net" {
  count = var.gpu_type == "A3 Mega"? 1 : 0
  source          = "./modules/embedded/modules/network/vpc"
  deployment_name = var.goog_cm_deployment_name
  project_id      = var.project_id
  region          = local.region != null ? local.region : error("Cannot find region for zone")
  secondary_ranges = {
    (local.subnetwork_name) = [{
      ip_cidr_range = "10.4.0.0/14"
      range_name    = "pods"
      }, {
      ip_cidr_range = "10.0.32.0/20"
      range_name    = "services"
    }]
  }
  subnetwork_name = local.subnetwork_name
}

module "gke-a3-mega-gpunets" {
  count = var.gpu_type == "A3 Mega"? 1 : 0
  source                  = "./modules/embedded/modules/network/multivpc"
  deployment_name         = var.goog_cm_deployment_name
  global_ip_address_range = "192.169.0.0/16"
  network_count           = 8
  network_name_prefix     = "${var.goog_cm_deployment_name}-gpunet"
  project_id              = var.project_id
  region          = local.region != null ? local.region : error("Cannot find region for zone")
  subnetwork_cidr_suffix  = 24
}

module "a3-megagpu-cluster" {
  count = var.gpu_type == "A3 Mega"? 1 : 0
  source                  = "./modules/embedded/modules/scheduler/gke-cluster"
  additional_networks     = flatten([module.gke-a3-mega-gpunets[0].additional_networks])
  deployment_name         = var.goog_cm_deployment_name
  enable_private_endpoint = false
  labels                  = var.labels
  master_authorized_networks = [{
    cidr_block   = var.authorized_cidr
    display_name = "kubectl-access-network"
  }]
  network_id           = module.gke-a3-mega-net[0].network_id
  project_id           = var.project_id
  region          = local.region != null ? local.region : error("Cannot find region for zone")
  subnetwork_self_link = module.gke-a3-mega-net[0].subnetwork_self_link
  enable_gcsfuse_csi   = true
  providers = {
    kubectl = kubectl
    http    = http
  }
}

module "a3_megagpu_pool" {
  count = var.gpu_type == "A3 Mega"? 1 : 0
  source                    = "./modules/embedded/modules/compute/gke-node-pool"
  additional_networks       = flatten([module.gke-a3-mega-gpunets[0].additional_networks])
  cluster_id                = local.gke_cluster_id
  gke_version               = local.gke_cluster_version
  # host_maintenance_interval = "PERIODIC"
  internal_ghpc_module_id   = "a3_megagpu_pool"
  labels                    = var.labels
  machine_type              = "a3-megagpu-8g"
  placement_policy = var.placement_policy_name == "" ? {
    policy_type = ""
  } : {
    policy_type = "COMPACT"
    policy_name = var.placement_policy_name
  }
  project_id        = var.project_id
  reservation_affinity = (var.reservation != "" ? {
      consume_reservation_type = "SPECIFIC_RESERVATION"
      specific_reservations = [{
	name = var.reservation_block == "" ? "${var.reservation}" : "${var.reservation}/reservationBlocks/${var.reservation_block}"
        project = var.project_id
      }]
    } : {
      consume_reservation_type = "NO_RESERVATION"
      specific_reservations    = []
    }
  )
  local_ssd_count_ephemeral_storage = 16
  static_node_count = local.node_count
  taints            = []
  zones             = [var.a3_mega_zone]
  providers = {
    kubectl = kubectl
    http    = http
  }
}

module "gke-a3-ultra-net-0" {
  count = var.gpu_type == "A3 Ultra"? 1 : 0
  source          = "./modules/embedded/modules/network/vpc"
  deployment_name = var.goog_cm_deployment_name
  firewall_rules = [{
    allow = [{
      ports    = ["0-65535"]
      protocol = "tcp"
      }, {
      ports    = ["0-65535"]
      protocol = "udp"
      }, {
      protocol = "icmp"
    }]
    name   = "${var.goog_cm_deployment_name}-internal-0"
    ranges = ["192.168.0.0/16"]
  }]
  labels       = var.labels
  network_name = "${var.goog_cm_deployment_name}-net-0"
  project_id   = var.project_id
  region       = local.region
  secondary_ranges_list = [{
    ranges = [{
      ip_cidr_range = "10.4.0.0/14"
      range_name    = "pods"
      }, {
      ip_cidr_range = "10.0.32.0/20"
      range_name    = "services"
    }]
    subnetwork_name = "${var.goog_cm_deployment_name}-sub-0"
  }]
  subnetworks = [{
    subnet_ip     = "192.168.0.0/18"
    subnet_name   = "${var.goog_cm_deployment_name}-sub-0"
    subnet_region = local.region
  }]
}

module "gke-a3-ultra-net-1" {
  count = var.gpu_type == "A3 Ultra"? 1 : 0
  source          = "./modules/embedded/modules/network/vpc"
  deployment_name = var.goog_cm_deployment_name
  firewall_rules = [{
    allow = [{
      ports    = ["0-65535"]
      protocol = "tcp"
      }, {
      ports    = ["0-65535"]
      protocol = "udp"
      }, {
      protocol = "icmp"
    }]
    name   = "${var.goog_cm_deployment_name}-internal-1"
    ranges = ["192.168.0.0/16"]
  }]
  labels       = var.labels
  mtu          = 8896
  network_name = "${var.goog_cm_deployment_name}-net-1"
  project_id   = var.project_id
  region       = local.region
  subnetworks = [{
    subnet_ip     = "192.168.64.0/18"
    subnet_name   = "${var.goog_cm_deployment_name}-sub-1"
    subnet_region = local.region
  }]
}

module "gke-a3-ultra-rdma-net" {
  count = var.gpu_type == "A3 Ultra"? 1 : 0
  source               = "./modules/embedded/modules/network/gpu-rdma-vpc"
  deployment_name      = var.goog_cm_deployment_name
  mtu                  = 8896
  network_name         = "${var.goog_cm_deployment_name}-rdma-net"
  network_profile      = "https://www.googleapis.com/compute/beta/projects/${var.project_id}/global/networkProfiles/${local.zone}-vpc-roce"
  network_routing_mode = "REGIONAL"
  project_id           = var.project_id
  region               = local.region
  subnetworks_template = {
    count       = 8
    ip_range    = "192.168.128.0/18"
    name_prefix = "${var.goog_cm_deployment_name}-rdma-sub"
    region      = local.region
  }
}

module "a3-ultragpu-cluster" {
  count = var.gpu_type == "A3 Ultra"? 1 : 0
  source                  = "./modules/embedded/modules/scheduler/gke-cluster"
  additional_networks     = concat([{ network = module.gke-a3-ultra-net-1[0].network_name, subnetwork = module.gke-a3-ultra-net-1[0].subnetwork_name, subnetwork_project = var.project_id, nic_type = "GVNIC", queue_count = null, network_ip = null, stack_type = null, access_config = [{ nat_ip = null, public_ptr_domain_name = null, network_tier = null }], ipv6_access_config = [], alias_ip_range = [] }], module.gke-a3-ultra-rdma-net[0].subnetwork_interfaces_gke)
  deployment_name         = var.goog_cm_deployment_name
  enable_dcgm_monitoring  = true
  enable_gcsfuse_csi      = true
  enable_private_endpoint = false
  labels                  = var.labels
  maintenance_exclusions = [{
    end_time        = "2025-12-22T00:00:00Z"
    exclusion_scope = "NO_MINOR_OR_NODE_UPGRADES"
    name            = "no-minor-or-node-upgrades-indefinite"
    start_time      = "2024-12-01T00:00:00Z"
  }]
  master_authorized_networks = [{
    cidr_block   = var.authorized_cidr
    display_name = "kubectl-access-network"
  }]
  network_id                    = module.gke-a3-ultra-net-0[0].network_id
  project_id                    = var.project_id
  region                        = local.region
  release_channel               = "RAPID"
  subnetwork_self_link          = module.gke-a3-ultra-net-0[0].subnetwork_self_link
  system_node_pool_disk_size_gb = 200
  system_node_pool_machine_type = "e2-standard-16"
  system_node_pool_taints       = []
  version_prefix                = "1.31."
  zone                          = local.zone
  providers = {
    kubectl    = kubectl
    http       = http
    kubernetes = kubernetes
  }
}

module "a3-ultragpu-pool" {
  count = var.gpu_type == "A3 Ultra"? 1 : 0
  source              = "./modules/embedded/modules/compute/gke-node-pool"
  additional_networks = concat([{ network = module.gke-a3-ultra-net-1[0].network_name, subnetwork = module.gke-a3-ultra-net-1[0].subnetwork_name, subnetwork_project = var.project_id, nic_type = "GVNIC", queue_count = null, network_ip = null, stack_type = null, access_config = [{ nat_ip = null, public_ptr_domain_name = null, network_tier = null }], ipv6_access_config = [], alias_ip_range = [] }], module.gke-a3-ultra-rdma-net[0].subnetwork_interfaces_gke)
  auto_upgrade        = true
  cluster_id          = local.gke_cluster_id
  disk_type           = "hyperdisk-balanced"
  gke_version         = local.gke_cluster_version
  guest_accelerator = [{
    count = 8
    gpu_driver_installation_config = {
      gpu_driver_version = "LATEST"
    }
    type = "nvidia-h200-141gb"
  }]
  internal_ghpc_module_id = "a3-ultragpu-pool"
  labels                  = var.labels
  machine_type            = "a3-ultragpu-8g"
  project_id              = var.project_id
  reservation_affinity = {
    consume_reservation_type = "SPECIFIC_RESERVATION"
    specific_reservations = [{
      name = var.reservation
    }]
  } 
  local_ssd_count_ephemeral_storage = 32
  static_node_count = local.node_count
  zones             = [local.zone]
  providers = {
    kubectl = kubectl
    http    = http
  }
}

module "topology-aware-scheduler-install" {
  count = var.gpu_type == "A3 Ultra"? 0 : 1
  source     = "./modules/embedded/community/modules/compute/gke-topology-scheduler"
  cluster_id = local.gke_cluster_id
  project_id = var.project_id
  providers = {
    kubectl = kubectl
    http    = http
  }
}

module "workload-manager-install" {
  source = "./modules/embedded/modules/management/kubectl-apply"
  cluster_id = local.gke_cluster_id
  jobset = {
    install = true
    version = "v0.7.2"
  }
  kueue = {
    install = true
    config_path = var.gpu_type == "A3 Ultra" ? "./modules/embedded/modules/management/kubectl-apply/templates/kueue-configuration.yaml.tftpl" : null
    config_template_vars = {
      node_pool_name = var.gpu_type == "A3 Ultra" ? module.a3-ultragpu-pool[0].node_pool_name : null
      num_gpus       = var.gpu_type == "A3 Ultra" ? module.a3-ultragpu-pool[0].static_gpu_count : null
    }
    version = "v0.10.0"
  }
  project_id = var.project_id
  providers = {
    kubectl = kubectl
    http    = http
  }
}

# created by replicating the helm install in https://github.com/AI-Hypercomputer/gpu-recipes/tree/main/training/a3mega/llama-3-70b/nemo-pretraining-gke
module "nemo" {
  source     = "./modules/nemo"
  cluster_id = local.gke_cluster_id
  checkpoint_bucket = local.result_bucket_name
  recipe = var.recipe
  node_count = local.node_count
  gpu_type = var.gpu_type
  # Providers needs to be explicitely passed in when a depends_on is present in a module.
  providers = {
    helm = helm
  }
  # The kueue install needs to finished completely or else the deployment of nemo workload throws error, thus adding the depends_on.
  depends_on = [module.workload-manager-install]
}

module "gcs" {
  source     = "./modules/gcs"
  project_id = var.project_id
  region          = local.region != null ? local.region : error("Cannot find region for zone")
  bucket_name     = local.result_bucket_name
}
