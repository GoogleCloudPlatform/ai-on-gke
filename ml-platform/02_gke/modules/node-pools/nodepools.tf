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

resource "google_container_node_pool" "node-pool" {
  name       = format("%s-%s",var.cluster_name,var.node_pool_name)
  project    = var.project_id
  cluster    = var.cluster_name
  location   = var.region
  node_config {
    machine_type = var.machine_type
    taint = var.taints
    labels = {
      "resource-type" : var.resource_type
    }

    guest_accelerator {
      type = var.accelerator
      count = var.accelerator_count
    }
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    dynamic "reservation_affinity" {
      for_each = var.reservation_name != "" ? [1] : [ ]
      content {
        consume_reservation_type = "SPECIFIC_RESERVATION"
        key = "compute.googleapis.com/reservation-name"
        values = [var.reservation_name]
      }
    }
  }
  autoscaling {
    total_min_node_count = var.autoscaling["total_min_node_count"]
    total_max_node_count = var.autoscaling["total_max_node_count"]
    location_policy      = var.autoscaling["location_policy"]
  }

  timeouts {
    create = "30m"
    update = "20m"
  }

  lifecycle {
    ignore_changes = [
      node_config[0].labels,
      node_config[0].taint,
    ]
  }
  network_config {
    enable_private_nodes = true
  }
}