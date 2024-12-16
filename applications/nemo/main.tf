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
  subnetwork_name = "${var.deployment_name}-gke-net"
}
module "network-kevinmcw" {
  source          = "./modules/embedded/modules/network/vpc"
  deployment_name = var.deployment_name
  project_id      = var.project_id
  region          = var.region
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

module "gpunets" {
  source                  = "./modules/embedded/modules/network/multivpc"
  deployment_name         = var.deployment_name
  global_ip_address_range = "192.169.0.0/16"
  network_count           = 8
  network_name_prefix     = "${var.deployment_name}-gpunet"
  project_id              = var.project_id
  region                  = var.region
  subnetwork_cidr_suffix  = 24
}

module "gke_cluster" {
  source                  = "./modules/embedded/modules/scheduler/gke-cluster"
  additional_networks     = flatten([module.gpunets.additional_networks])
  deployment_name         = var.deployment_name
  enable_private_endpoint = false
  labels                  = var.labels
  master_authorized_networks = [{
    cidr_block   = var.authorized_cidr
    display_name = "kubectl-access-network"
  }]
  network_id           = module.network-kevinmcw.network_id
  project_id           = var.project_id
  region               = var.region
  subnetwork_self_link = module.network-kevinmcw.subnetwork_self_link
}

module "a3_megagpu_pool" {
  source                    = "./modules/embedded/modules/compute/gke-node-pool"
  additional_networks       = flatten([module.gpunets.additional_networks])
  cluster_id                = module.gke_cluster.cluster_id
  gke_version               = module.gke_cluster.gke_version
  host_maintenance_interval = "PERIODIC"
  internal_ghpc_module_id   = "a3_megagpu_pool"
  labels                    = var.labels
  machine_type              = "a3-megagpu-8g"
  placement_policy = {
    type = "COMPACT"
  }
  project_id        = var.project_id
  taints            = []
  zones             = [var.zone]
}

module "topology_aware_scheduler_install" {
  source     = "./modules/embedded/community/modules/compute/gke-topology-scheduler"
  cluster_id = module.gke_cluster.cluster_id
  project_id = var.project_id
}

module "workload_manager_install" {
  source     = "./modules/embedded/modules/management/kubectl-apply"
  cluster_id = module.gke_cluster.cluster_id
  jobset = {
    install = true
  }
  kueue = {
    install = true
  }
  project_id = var.project_id
}

# created by replicating the helm install in https://github.com/AI-Hypercomputer/gpu-recipes/tree/main/training/a3mega/llama-3-70b/nemo-pretraining-gke
module "nemo" {
  source     = "./modules/nemo"
  cluster_id = module.gke_cluster.cluster_id
  checkpoint_bucket = var.checkpoint_bucket
  gpus = tonumber(var.gpus)
  # Providers needs to be explicitely passed in when a depends_on is present in a module.
  providers = {
    helm = helm
  }
  # The kueue install needs to finished completely or else the deployment of nemo workload throws error, thus adding the depends_on.
  depends_on = [module.workload_manager_install]
}
