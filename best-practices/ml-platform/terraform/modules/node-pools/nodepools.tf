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
  cluster  = var.cluster_name
  location = var.region
  name     = format("%s-%s", var.cluster_name, var.node_pool_name)
  project  = var.project_id

  autoscaling {
    location_policy      = var.autoscaling["location_policy"]
    total_max_node_count = var.autoscaling["total_max_node_count"]
    total_min_node_count = var.autoscaling["total_min_node_count"]
  }

  network_config {
    enable_private_nodes = true
  }

  node_config {
    machine_type = var.machine_type
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      "resource-type" : var.resource_type
    }

    gcfs_config {
      enabled = true
    }

    guest_accelerator {
      count = var.accelerator_count
      type  = var.accelerator
    }

    dynamic "reservation_affinity" {
      for_each = var.reservation_name != "" ? [1] : []
      content {
        consume_reservation_type = "SPECIFIC_RESERVATION"
        key                      = "compute.googleapis.com/reservation-name"
        values                   = [var.reservation_name]
      }
    }

    shielded_instance_config {
      enable_integrity_monitoring = true
      enable_secure_boot          = true
    }

    dynamic "taint" {
      for_each = var.taints
      content {
        effect = taint.value.effect
        key    = taint.value.key
        value  = taint.value.value
      }
    }
  }

  lifecycle {
    ignore_changes = [
      node_config[0].labels,
      node_config[0].taint,
    ]
  }

  timeouts {
    create = "30m"
    update = "20m"
  }
}
