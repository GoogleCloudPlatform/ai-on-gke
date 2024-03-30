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

variable "create_router" {
  default     = false
  description = "Create router instead of using an existing one, uses 'router' variable for new resource name."
  type        = bool
}

variable "enable_dynamic_port_allocation" {
  default     = false
  description = "Enable Dynamic Port Allocation. If minPorts is set, minPortsPerVm must be set to a power of two greater than or equal to 32."
  type        = bool
}

variable "enable_endpoint_independent_mapping" {
  default     = null
  description = "Specifies if endpoint independent mapping is enabled."
  type        = bool
}

variable "icmp_idle_timeout_sec" {
  default     = "30"
  description = "Timeout (in seconds) for ICMP connections. Defaults to 30s if not set. Changing this forces a new NAT to be created."
  type        = string
}

variable "log_config_enable" {
  default     = false
  description = "Indicates whether or not to export logs"
  type        = bool
}

variable "log_config_filter" {
  default     = "ALL"
  description = "Specifies the desired filtering of logs on this NAT. Valid values are: \"ERRORS_ONLY\", \"TRANSLATIONS_ONLY\", \"ALL\""
  type        = string
}

variable "max_ports_per_vm" {
  default     = null
  description = "Maximum number of ports allocated to a VM from this NAT. This field can only be set when enableDynamicPortAllocation is enabled.This will be ignored if enable_dynamic_port_allocation is set to false."
  type        = string
}

variable "min_ports_per_vm" {
  default     = "64"
  description = "Minimum number of ports allocated to a VM from this NAT config. Defaults to 64 if not set. Changing this forces a new NAT to be created."
  type        = string
}

variable "name" {
  default     = ""
  description = "Defaults to 'cloud-nat-RANDOM_SUFFIX'. Changing this forces a new NAT to be created."
  type        = string
}

variable "nat_ips" {
  default     = []
  description = "List of self_links of external IPs. Changing this forces a new NAT to be created. Value of `nat_ip_allocate_option` is inferred based on nat_ips. If present set to MANUAL_ONLY, otherwise AUTO_ONLY."
  type        = list(string)
}

variable "network" {
  default     = ""
  description = "VPN name, only if router is not passed in and is created by the module."
  type        = string
}

variable "project_id" {
  description = "The project ID to deploy to"
  type        = string
}

variable "region" {
  description = "The region to deploy to"
  type        = string
}

variable "router" {
  description = "The name of the router in which this NAT will be configured. Changing this forces a new NAT to be created."
  type        = string
}

variable "router_asn" {
  default     = "64514"
  description = "Router ASN, only if router is not passed in and is created by the module."
  type        = string
}

variable "router_keepalive_interval" {
  default     = "20"
  description = "Router keepalive_interval, only if router is not passed in and is created by the module."
  type        = string
}

variable "source_subnetwork_ip_ranges_to_nat" {
  default     = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  description = "Defaults to ALL_SUBNETWORKS_ALL_IP_RANGES. How NAT should be configured per Subnetwork. Valid values include: ALL_SUBNETWORKS_ALL_IP_RANGES, ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES, LIST_OF_SUBNETWORKS. Changing this forces a new NAT to be created."
  type        = string
}

variable "subnetworks" {
  default     = []
  description = "Specifies one or more subnetwork NAT configurations"
  type = list(object({
    name                     = string,
    secondary_ip_range_names = list(string)
    source_ip_ranges_to_nat  = list(string)
  }))
}

variable "tcp_established_idle_timeout_sec" {
  default     = "1200"
  description = "Timeout (in seconds) for TCP established connections. Defaults to 1200s if not set. Changing this forces a new NAT to be created."
  type        = string
}

variable "tcp_time_wait_timeout_sec" {
  default     = "120"
  description = "Timeout (in seconds) for TCP connections that are in TIME_WAIT state. Defaults to 120s if not set."
  type        = string
}

variable "tcp_transitory_idle_timeout_sec" {
  default     = "30"
  description = "Timeout (in seconds) for TCP transitory connections. Defaults to 30s if not set. Changing this forces a new NAT to be created."
  type        = string
}

variable "udp_idle_timeout_sec" {
  default     = "30"
  description = "Timeout (in seconds) for UDP connections. Defaults to 30s if not set. Changing this forces a new NAT to be created."
  type        = string
}
