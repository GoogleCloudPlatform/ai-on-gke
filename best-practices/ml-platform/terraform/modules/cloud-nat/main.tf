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

resource "random_string" "name_suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  default_name           = "cloud-nat-${random_string.name_suffix.result}"
  name                   = var.name != "" ? var.name : local.default_name
  nat_ip_allocate_option = length(var.nat_ips) > 0 ? "MANUAL_ONLY" : "AUTO_ONLY"
  router                 = var.create_router ? google_compute_router.router[0].name : var.router
}

resource "google_compute_router" "router" {
  count = var.create_router ? 1 : 0

  name    = var.router
  network = var.network
  project = var.project_id
  region  = var.region

  bgp {
    asn                = var.router_asn
    keepalive_interval = var.router_keepalive_interval
  }
}

resource "google_compute_router_nat" "main" {
  enable_dynamic_port_allocation      = var.enable_dynamic_port_allocation
  enable_endpoint_independent_mapping = var.enable_endpoint_independent_mapping
  icmp_idle_timeout_sec               = var.icmp_idle_timeout_sec
  max_ports_per_vm                    = var.enable_dynamic_port_allocation ? var.max_ports_per_vm : null
  min_ports_per_vm                    = var.min_ports_per_vm
  name                                = local.name
  nat_ip_allocate_option              = local.nat_ip_allocate_option
  nat_ips                             = var.nat_ips
  project                             = var.project_id
  region                              = var.region
  router                              = local.router
  source_subnetwork_ip_ranges_to_nat  = var.source_subnetwork_ip_ranges_to_nat
  tcp_established_idle_timeout_sec    = var.tcp_established_idle_timeout_sec
  tcp_time_wait_timeout_sec           = var.tcp_time_wait_timeout_sec
  tcp_transitory_idle_timeout_sec     = var.tcp_transitory_idle_timeout_sec
  udp_idle_timeout_sec                = var.udp_idle_timeout_sec

  dynamic "log_config" {
    for_each = var.log_config_enable == true ? [{
      enable = var.log_config_enable
      filter = var.log_config_filter
    }] : []

    content {
      enable = log_config.value.enable
      filter = log_config.value.filter
    }
  }

  dynamic "subnetwork" {
    for_each = var.subnetworks
    content {
      name                     = subnetwork.value.name
      source_ip_ranges_to_nat  = subnetwork.value.source_ip_ranges_to_nat
      secondary_ip_range_names = contains(subnetwork.value.source_ip_ranges_to_nat, "LIST_OF_SECONDARY_IP_RANGES") ? subnetwork.value.secondary_ip_range_names : []
    }
  }
}
