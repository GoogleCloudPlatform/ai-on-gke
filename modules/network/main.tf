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

module "custom-network" {
  source       = "terraform-google-modules/network/google"
  version      = "8.0.0"
  count        = var.create_network ? 1 : 0
  project_id   = var.project_id
  network_name = var.network_name

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

// TODO: Migrate to terraform-google-modules/sql-db/google//modules/private_service_access (below)
// once https://github.com/terraform-google-modules/terraform-google-sql-db/issues/585 is resolved.
// We define a VPC peering subnet that will be peered with the
// Cloud SQL instance network. The Cloud SQL instance will
// have a private IP within the provided range.
// https://cloud.google.com/vpc/docs/configure-private-services-access

resource "google_compute_global_address" "google-managed-services-range" {
  count         = var.create_network ? 1 : 0
  project       = var.project_id
  name          = "google-managed-services-${var.network_name}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = local.network_self_link
}

# Creates the peering with the producer network.
resource "google_service_networking_connection" "private_service_access" {
  count                   = var.create_network ? 1 : 0
  network                 = local.network_self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.google-managed-services-range[0].name]
  # This will enable a successful terraform destroy when destroying CloudSQL instances
  deletion_policy = "ABANDON"
}

locals {
  network_name      = var.create_network ? module.custom-network[0].network_name : var.network_name
  subnetwork_name   = var.create_network ? module.custom-network[0].subnets_names[0] : var.subnetwork_name
  network_self_link = var.create_network ? module.custom-network[0].network_self_link : data.google_compute_network.existing-network[0].self_link
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
