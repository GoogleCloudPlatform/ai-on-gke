# Copyright 2023 Google LLC
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

locals {
  team_a_namespace = var.team_a_namespace
  team_b_namespace = var.team_b_namespace
  team_c_namespace = var.team_c_namespace
  team_d_namespace = var.team_d_namespace
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${resource.google_container_cluster.gke_batch.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.gke_batch.ca_certificate)
}

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_container_cluster" "gke_batch" {
  deletion_protection = false
  provider            = google-beta
  name                = "gke-batch-refarch"
  project             = var.project_id
  location            = var.region
  node_locations      = ["${var.region}-a", "${var.region}-b", "${var.region}-c"]
  initial_node_count  = 2
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.32/28"
  }
  ip_allocation_policy {}
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  # Adding gcfs_config to enable image streaming on the cluster.
  node_pool_defaults {
    node_config_defaults {
      gcfs_config {
        enabled = true
      }
    }
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
      maximum       = 1000
    }
    resource_limits {
      resource_type = "memory"
      minimum       = 16
      maximum       = 4000
    }
    resource_limits {
      resource_type = "nvidia-tesla-t4"
      maximum       = 300
    }
    resource_limits {
      resource_type = "nvidia-l4"
      maximum       = 300
    }
    resource_limits {
      resource_type = "nvidia-tesla-a100"
      maximum       = 100
    }
    resource_limits {
      resource_type = "nvidia-a100-80gb"
      maximum       = 100
    }
    resource_limits {
      resource_type = "nvidia-tesla-v100"
      maximum       = 100
    }
    resource_limits {
      resource_type = "nvidia-tesla-p100"
      maximum       = 100
    }
    resource_limits {
      resource_type = "nvidia-tesla-p4"
      maximum       = 100
    }
    resource_limits {
      resource_type = "nvidia-tesla-k80"
      maximum       = 100
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
  release_channel {
    channel = "RAPID"
  }

}

# Reservation for instances with GPUs
resource "google_compute_reservation" "machine_reservation" {
  project                       = var.project_id
  specific_reservation_required = true
  name                          = "machine-reservation"
  zone                          = var.zone
  specific_reservation {
    count = var.machine_reservation_count
    instance_properties {
      machine_type = var.machine_type
      guest_accelerators {
        accelerator_type  = var.accelerator
        accelerator_count = var.accelerator_count
      }
    }
  }
}

# Nodepool to consume reservation for instances with GPUs
resource "google_container_node_pool" "reserved_np" {
  project        = var.project_id
  name           = "reserved-np"
  cluster        = resource.google_container_cluster.gke_batch.name
  node_count     = var.machine_reservation_count
  node_locations = ["${var.zone}"]
  location       = resource.google_container_cluster.gke_batch.location
  node_config {
    machine_type = var.machine_type
    dynamic "taint" {
      for_each = var.reserved_taints
      content {
        key    = taint.value.key
        value  = taint.value.taint_value
        effect = taint.value.effect
      }
    }
    labels = {
      "resource-type" : "reservation"
    }

    guest_accelerator {
      type  = var.accelerator
      count = var.accelerator_count
    }

    reservation_affinity {
      consume_reservation_type = "SPECIFIC_RESERVATION"
      key                      = "compute.googleapis.com/reservation-name"
      values                   = ["machine-reservation"]
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
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
}

# Nodepool to spill over high priority workloads from reserved to on-demand instances with GPUs
resource "google_container_node_pool" "ondemand_np" {
  depends_on = [google_container_node_pool.reserved_np]
  name       = "ondemand-np"
  project    = var.project_id
  cluster    = resource.google_container_cluster.gke_batch.name
  location   = var.region
  node_config {
    machine_type = var.machine_type
    dynamic "taint" {
      for_each = var.ondemand_taints
      content {
        key    = taint.value.key
        value  = taint.value.taint_value
        effect = taint.value.effect
      }
    }
    labels = {
      "resource-type" : "ondemand"
    }

    guest_accelerator {
      type  = var.accelerator
      count = var.accelerator_count
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  autoscaling {
    total_min_node_count = 0
    total_max_node_count = 24
    location_policy      = "ANY"
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
}

# Nodepool to spill over low priority workloads from reserved to Spot instances with GPUs
resource "google_container_node_pool" "spot_np" {
  depends_on = [google_container_node_pool.ondemand_np]
  name       = "spot-np"
  project    = var.project_id
  cluster    = resource.google_container_cluster.gke_batch.name
  location   = var.region
  node_config {
    machine_type = var.machine_type
    spot         = true
    dynamic "taint" {
      for_each = var.spot_taints
      content {
        key    = taint.value.key
        value  = taint.value.taint_value
        effect = taint.value.effect
      }
    }
    labels = {
      "resource-type" : "spot"
    }

    guest_accelerator {
      type  = var.accelerator
      count = var.accelerator_count
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  autoscaling {
    total_min_node_count = 0
    total_max_node_count = 36
    location_policy      = "ANY"
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
}

# Cloud Router and NAT for private nodes to communicate externally
resource "google_compute_router" "router" {
  name    = "router"
  network = "default"
  region  = var.region
}

resource "google_compute_router_nat" "nat_gateway" {
  name                               = "nat-gateway"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}


# Workload Identity for team-a
resource "google_service_account" "wi_team_a" {
  account_id   = "wi-team-a"
  display_name = "team-a Service Account"
}

resource "google_project_iam_member" "wi_team_a_monitoring_metricwriter" {
  member  = google_service_account.wi_team_a.member
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
}

resource "google_project_iam_member" "wi_team_a_logging_logwriter" {
  member  = google_service_account.wi_team_a.member
  project = var.project_id
  role    = "roles/logging.logWriter"
}

resource "google_project_iam_member" "wi_team_a_storage_admin" {
  member  = google_service_account.wi_team_a.member
  project = var.project_id
  role    = "roles/storage.admin"
}

resource "google_service_account_iam_binding" "wi_team_a_iam_wi_user" {
  depends_on = [google_container_cluster.gke_batch]

  service_account_id = google_service_account.wi_team_a.name
  role               = "roles/iam.workloadIdentityUser"

  members = ["serviceAccount:${var.project_id}.svc.id.goog[${local.team_a_namespace}/${local.team_a_namespace}-ksa]"]
}


# Workload Identity for team-b
resource "google_service_account" "wi_team_b" {
  account_id   = "wi-team-b"
  display_name = "team-b Service Account"
}

resource "google_project_iam_member" "wi_team_b_monitoring_metricwriter" {
  member  = google_service_account.wi_team_b.member
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
}

resource "google_project_iam_member" "wi_team_b_logging_logwriter" {
  member  = google_service_account.wi_team_b.member
  project = var.project_id
  role    = "roles/logging.logWriter"
}

resource "google_project_iam_member" "wi_team_b_storage_admin" {
  member  = google_service_account.wi_team_b.member
  project = var.project_id
  role    = "roles/storage.admin"
}

resource "google_service_account_iam_binding" "wi_team_b_iam_wi_user" {
  depends_on = [google_container_cluster.gke_batch]

  service_account_id = google_service_account.wi_team_b.name
  role               = "roles/iam.workloadIdentityUser"

  members = ["serviceAccount:${var.project_id}.svc.id.goog[${local.team_b_namespace}/${local.team_b_namespace}-ksa]"]
}


# Workload Identity for team-c
resource "google_service_account" "wi_team_c" {
  account_id   = "wi-team-c"
  display_name = "team-c Service Account"
}

resource "google_project_iam_member" "wi_team_c_monitoring_metricwriter" {
  member  = google_service_account.wi_team_c.member
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
}

resource "google_project_iam_member" "wi_team_c_logging_logwriter" {
  member  = google_service_account.wi_team_c.member
  project = var.project_id
  role    = "roles/logging.logWriter"
}

resource "google_project_iam_member" "wi_team_c_storage_admin" {
  member  = google_service_account.wi_team_c.member
  project = var.project_id
  role    = "roles/storage.admin"
}

resource "google_service_account_iam_binding" "wi_team_c_iam_wi_user" {
  depends_on = [google_container_cluster.gke_batch]

  service_account_id = google_service_account.wi_team_c.name
  role               = "roles/iam.workloadIdentityUser"

  members = ["serviceAccount:${var.project_id}.svc.id.goog[${local.team_c_namespace}/${local.team_c_namespace}-ksa]"]
}

# Workload Identity for team-d
resource "google_service_account" "wi_team_d" {
  account_id   = "wi-team-d"
  display_name = "team-d Service Account"
}

resource "google_project_iam_member" "wi_team_d_monitoring_metricwriter" {
  member  = google_service_account.wi_team_d.member
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
}

resource "google_project_iam_member" "wi_team_d_logging_logwriter" {
  member  = google_service_account.wi_team_d.member
  project = var.project_id
  role    = "roles/logging.logWriter"
}

resource "google_project_iam_member" "wi_team_d_storage_admin" {
  member  = google_service_account.wi_team_d.member
  project = var.project_id
  role    = "roles/storage.admin"
}

resource "google_service_account_iam_binding" "wi_team_d_iam_wi_user" {
  depends_on = [google_container_cluster.gke_batch]

  service_account_id = google_service_account.wi_team_d.name
  role               = "roles/iam.workloadIdentityUser"

  members = ["serviceAccount:${var.project_id}.svc.id.goog[${local.team_d_namespace}/${local.team_d_namespace}-ksa]"]
}
