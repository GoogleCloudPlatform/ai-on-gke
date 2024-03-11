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

resource "google_compute_network" "vpc-network" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = var.routing_mode
}

resource "google_compute_subnetwork" "subnet-1" {
  project                  = var.project_id
  name                     = var.subnet_01_name
  ip_cidr_range            = var.subnet_01_ip
  region                   = var.subnet_01_region
  network                  = google_compute_network.vpc-network.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "subnet-2" {
  project                  = var.project_id
  name                     = var.subnet_02_name
  ip_cidr_range            = var.subnet_02_ip
  region                   = var.subnet_02_region
  network                  = google_compute_network.vpc-network.id
  private_ip_google_access = true
}

//resource "google_compute_route" "default-route" {
//name        = var.default_route_name
//dest_range  = "0.0.0.0/0"
//network     = google_compute_network.vpc-network.id
//priority    = 1000
//next_hop_gateway = "default-internet-gateway"
//}
