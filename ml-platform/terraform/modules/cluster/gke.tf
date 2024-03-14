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

data "google_client_config" "default" {}

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_container_cluster" "gke_batch" {
  provider            = google-beta
  deletion_protection = false
  name                = var.cluster_name
  project             = var.project_id
  location            = var.region
  network             = var.network
  subnetwork          = var.subnet
  node_locations      = ["${var.region}-a", "${var.region}-b", "${var.region}-c"]
  initial_node_count  = 2
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  addons_config {
    gcp_filestore_csi_driver_config {
      enabled = true
    }
    gcs_fuse_csi_driver_config {
      enabled = true
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }
  cluster_autoscaling {
    enabled             = true
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
    resource_limits {
      resource_type = "cpu"
      minimum       = 4
      maximum       = 600
    }
    resource_limits {
      resource_type = "memory"
      minimum       = 16
      maximum       = 2400
    }
    resource_limits {
      resource_type = "nvidia-tesla-t4"
      maximum       = 300
    }
    resource_limits {
      resource_type = "nvidia-l4"
      maximum       = 30
    }
    resource_limits {
      resource_type = "nvidia-tesla-a100"
      maximum       = 50
    }
    resource_limits {
      resource_type = "nvidia-a100-80gb"
      maximum       = 30
    }
    resource_limits {
      resource_type = "nvidia-tesla-v100"
      maximum       = 30
    }
    resource_limits {
      resource_type = "nvidia-tesla-p100"
      maximum       = 30
    }
    resource_limits {
      resource_type = "nvidia-tesla-p4"
      maximum       = 30
    }
    resource_limits {
      resource_type = "nvidia-tesla-k80"
      maximum       = 30
    }
    auto_provisioning_defaults {
      management {
        auto_repair  = true
        auto_upgrade = true
      }

      upgrade_settings {
        strategy        = "SURGE"
        max_surge       = 0
        max_unavailable = 1
      }

      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }
  logging_config {
    enable_components = [
      "APISERVER",
      "CONTROLLER_MANAGER",
      "SCHEDULER",
      "SYSTEM_COMPONENTS",
      "WORKLOADS"
    ]
  }
  monitoring_config {
    enable_components = [
      "APISERVER",
      "CONTROLLER_MANAGER",
      "DAEMONSET",
      "DEPLOYMENT",
      "HPA",
      "POD",
      "SCHEDULER",
      "STATEFULSET",
      "STORAGE",
      "SYSTEM_COMPONENTS"
    ]
    managed_prometheus {
      enabled = true
    }
  }
  node_pool_defaults {
    node_config_defaults {
      gcfs_config {
        enabled = true
      }
    }
  }
  release_channel {
    channel = "STABLE"
  }
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "172.16.0.32/28"
  }
  master_authorized_networks_config {

    cidr_blocks {
      cidr_block   = var.master_auth_networks_ipcidr
      display_name = "vpc-cidr"
    }
  }
  ip_allocation_policy {}
}
