# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

data "google_compute_network" "existing-network" {
  count   = var.create_network ? 0 : 1
  name    = var.network_name
  project = var.project_id
}

data "google_compute_subnetwork" "subnetwork" {
  count   = var.create_network ? 0 : 1
  name    = var.subnetwork_name
  region  = var.subnetwork_region
  project = var.project_id
}

module "custom-network" {
  source       = "../gcp-network"
  count        = var.create_network ? 1 : 0
  project_id   = var.project_id
  network_name = var.network_name
  create_psa   = true

  subnets = [
    {
      subnet_name           = var.subnetwork_name
      subnet_ip             = var.subnetwork_cidr
      subnet_region         = var.subnetwork_region
      subnet_private_access = var.subnetwork_private_access
      description           = var.subnetwork_description
    }
  ]
}

## configure cloud NAT for private GKE
module "cloud-nat" {
  source        = "terraform-google-modules/cloud-nat/google"
  version       = "5.0.0"
  count         = var.create_network && var.private_cluster ? 1 : 0
  region        = var.region
  project_id    = var.project_id
  create_router = true
  router        = "${var.network_name}-router"
  name          = "cloud-nat-${var.network_name}-router"
  network       = module.custom-network[0].network_name
}
