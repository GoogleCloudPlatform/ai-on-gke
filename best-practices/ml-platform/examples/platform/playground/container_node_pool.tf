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

resource "google_container_node_pool" "gpu_h100x8_a3h8_dws" {
  depends_on = [
    module.gke
  ]

  cluster  = module.gke.cluster_name
  location = var.subnet_01_region
  name     = "gpu-h100x8-a3h8-dws"
  node_locations = [
    "${var.subnet_01_region}-a",
    "${var.subnet_01_region}-c"
  ]
  project = data.google_project.environment.project_id

  autoscaling {
    total_min_node_count = 0
    total_max_node_count = 1000
    location_policy      = "ANY"
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

  node_config {
    labels = {
      "resource-type" : "dws-ondemand"
    }
    machine_type    = "a3-highgpu-8g"
    service_account = google_service_account.cluster.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    ephemeral_storage_local_ssd_config {
      local_ssd_count = 16
    }

    gcfs_config {
      enabled = true
    }

    guest_accelerator {
      type  = "nvidia-h100-80gb"
      count = 8
    }

    reservation_affinity {
      consume_reservation_type = "NO_RESERVATION"
    }

    shielded_instance_config {
      enable_integrity_monitoring = true
      enable_secure_boot          = true
    }

    dynamic "taint" {
      for_each = var.ondemand_taints
      content {
        effect = taint.value.effect
        key    = taint.value.key
        value  = taint.value.value
      }
    }
  }

  queued_provisioning {
    enabled = true
  }

  timeouts {
    create = "30m"
    update = "20m"
  }
}
