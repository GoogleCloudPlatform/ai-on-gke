# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

data "terraform_remote_state" "gcp-projects" {
  count = length(keys("${var.project_id}")) == 0 ? 1 : 0
  backend = "gcs"
  config = {
    bucket  = var.lookup_state_bucket
    prefix  = "01_gcp_project"
  }
}

locals {
  parsed_project_id = length(keys("${var.project_id}")) == 0 ? data.terraform_remote_state.gcp-projects[0].outputs.project_ids : var.project_id
}

module "create-vpc" {
  for_each = local.parsed_project_id
  source = "./modules/network"
  project_id   = each.value
  network_name    = format("%s-%s",var.network_name,each.key)
  routing_mode    = var.routing_mode
  subnet_01_name      = format("%s-%s",var.subnet_01_name,each.key)
  subnet_01_ip        = var.subnet_01_ip
  subnet_01_region    = var.subnet_01_region
  subnet_02_name      = format("%s-%s",var.subnet_02_name,each.key)
  subnet_02_ip        = var.subnet_02_ip
  subnet_02_region    = var.subnet_02_region
  #default_route_name  = format("%s-%s","default-route",each.key)
}

resource "google_gke_hub_feature" "configmanagement_acm_feature" {
  count    = length(distinct(values(local.parsed_project_id)))
  name     = "configmanagement"
  project  = distinct(values(local.parsed_project_id))[count.index]
  location = "global"
  provider = google-beta
}

module "gke" {
  for_each = local.parsed_project_id
  source = "./modules/cluster"
  cluster_name   = format("%s-%s",var.cluster_name,each.key)
  network = module.create-vpc[each.key].vpc
  subnet  =  module.create-vpc[each.key].subnet-1
  project_id = each.value
  region = var.subnet_01_region
  zone = "${var.subnet_01_region}-a"
  master_auth_networks_ipcidr =  var.subnet_01_ip
  depends_on = [ google_gke_hub_feature.configmanagement_acm_feature ]
  env = each.key
}
module "reservation" {
  for_each = local.parsed_project_id
  source = "./modules/vm-reservations"
  cluster_name   = module.gke[each.key].cluster_name
  zone = "${var.subnet_01_region}-a"
  project_id = each.value
  depends_on = [ module.gke ]
}
module "node_pool-reserved" {
  for_each = local.parsed_project_id
  source = "./modules/node-pools"
  node_pool_name = "reservation"
  project_id = each.value
  cluster_name   = module.gke[each.key].cluster_name
  region = "${var.subnet_01_region}"
  taints = var.reserved_taints
  resource_type = "reservation"
  reservation_name = module.reservation[each.key].reservation_name
}

module "node_pool-ondemand" {
  for_each = local.parsed_project_id
  source = "./modules/node-pools"
  node_pool_name = "ondemand"
  project_id = each.value
  cluster_name   = module.gke[each.key].cluster_name
  region = "${var.subnet_01_region}"
  taints = var.ondemand_taints
  resource_type = "ondemand"
}

module "node_pool-spot" {
  for_each = local.parsed_project_id
  source = "./modules/node-pools"
  node_pool_name = "spot"
  project_id = each.value
  cluster_name   = module.gke[each.key].cluster_name
  region = "${var.subnet_01_region}"
  taints = var.spot_taints
  resource_type = "spot"

}

module "cloud-nat" {
  for_each              = local.parsed_project_id
  source                = "./modules/cloud-nat"
  project_id            = each.value
  region                = split("/", module.create-vpc[each.key].subnet-1)[3]
  name                  = format("%s-%s","nat-for-acm",each.key)
  network               = module.create-vpc[each.key].vpc
  create_router         = true
  router                = format("%s-%s","router-for-acm",each.key)
  depends_on            = [ module.create-vpc ]
}
