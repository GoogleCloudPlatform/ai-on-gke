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

resource "google_compute_network" "platform_eng" {
  auto_create_subnetworks  = false
  enable_ula_internal_ipv6 = true
  name                     = "primary"
  project                  = data.google_project.platform_eng.project_id
}

resource "google_compute_subnetwork" "platform_eng" {
  ip_cidr_range    = "10.0.0.0/16"
  ipv6_access_type = "INTERNAL"
  name             = var.platform_eng_region
  network          = google_compute_network.platform_eng.id
  project          = google_compute_network.platform_eng.project
  region           = var.platform_eng_region
  stack_type       = "IPV4_IPV6"

  lifecycle {
    ignore_changes = [
      secondary_ip_range
    ]
  }

  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "192.168.0.0/24"
  }

  secondary_ip_range {
    range_name    = "pod-ranges"
    ip_cidr_range = "192.168.1.0/24"
  }
}
