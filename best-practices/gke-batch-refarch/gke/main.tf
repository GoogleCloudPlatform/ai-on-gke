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

data "google_container_cluster" "gke_cluster" {
  name     = "batch-dev"
  location = var.region
}

data "google_project" "project" {
  project_id = var.project_id
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
  cluster        = data.google_container_cluster.gke_cluster.name
  node_count     = var.machine_reservation_count
  node_locations = ["${var.zone}"]
  location       = var.region
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
  name           = "ondemand-np"
  project        = var.project_id
  cluster        = data.google_container_cluster.gke_cluster.name
  location       = var.region
  node_locations = ["${var.region}-a", "${var.region}-b", "${var.region}-c"]
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
  name           = "spot-np"
  project        = var.project_id
  cluster        = data.google_container_cluster.gke_cluster.name
  location       = var.region
  node_locations = ["${var.region}-a", "${var.region}-b", "${var.region}-c"]
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

  service_account_id = google_service_account.wi_team_d.name
  role               = "roles/iam.workloadIdentityUser"

  members = ["serviceAccount:${var.project_id}.svc.id.goog[${local.team_d_namespace}/${local.team_d_namespace}-ksa]"]
}