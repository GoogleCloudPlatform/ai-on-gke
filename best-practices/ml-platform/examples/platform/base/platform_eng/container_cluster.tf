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

locals {
  # https://github.com/hashicorp/terraform-provider-google/issues/13325
  platform_eng_connect_gateway_host_url = "https://connectgateway.googleapis.com/v1/projects/${data.google_project.platform_eng.number}/locations/global/gkeMemberships/${google_gke_hub_membership.platform_eng_cluster.membership_id}"
  platform_eng_cluster_name             = "platform-eng"
  # Minimal roles for cluster SA https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa
  platform_eng_cluster_sa_roles = [
    "roles/monitoring.viewer",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/autoscaling.metricsWriter",
    "roles/artifactregistry.reader",
    "roles/serviceusage.serviceUsageConsumer"
  ]
}

# Create dedicated service account for node pools
resource "google_service_account" "platform_eng_cluster" {
  project      = data.google_project.platform_eng.project_id
  account_id   = "vm-${local.platform_eng_cluster_name}"
  display_name = "${local.platform_eng_cluster_name} Service Account"
  description  = "Terraform-managed service account for cluster ${local.platform_eng_cluster_name}"
}

# Bind minimum role list + additional roles to nodepool SA on project
resource "google_project_iam_member" "platform_eng_cluster_sa" {
  for_each = toset(local.platform_eng_cluster_sa_roles)
  project  = data.google_project.platform_eng.project_id
  member   = google_service_account.platform_eng_cluster.member
  role     = each.value
}

resource "google_container_cluster" "platform_eng" {
  provider = google-beta

  datapath_provider        = "ADVANCED_DATAPATH"
  deletion_protection      = false
  enable_autopilot         = true
  enable_l4_ilb_subsetting = true
  location                 = google_compute_subnetwork.platform_eng.region
  name                     = local.platform_eng_cluster_name
  network                  = google_compute_subnetwork.platform_eng.network
  project                  = data.google_project.platform_eng.project_id
  subnetwork               = google_compute_subnetwork.platform_eng.name

  addons_config {
    gcs_fuse_csi_driver_config {
      enabled = true
    }

    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  cluster_autoscaling {
    autoscaling_profile = "OPTIMIZE_UTILIZATION"

    auto_provisioning_defaults {
      service_account = google_service_account.platform_eng_cluster.email
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]

      management {
        auto_repair  = true
        auto_upgrade = true
      }

    }
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  ip_allocation_policy {
    stack_type                    = "IPV4_IPV6"
    services_secondary_range_name = google_compute_subnetwork.platform_eng.secondary_ip_range[0].range_name
    cluster_secondary_range_name  = google_compute_subnetwork.platform_eng.secondary_ip_range[1].range_name
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

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = google_compute_subnetwork.platform_eng.ip_cidr_range
      display_name = "vpc-cidr"
    }
  }

  monitoring_config {
    advanced_datapath_observability_config {
      enable_metrics = true
    }

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

  private_cluster_config {
    enable_private_endpoint = true
    enable_private_nodes    = true
  }

  release_channel {
    channel = "RAPID"
  }

  secret_manager_config {
    enabled = true
  }

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_ENTERPRISE"
  }

  workload_identity_config {
    workload_pool = "${data.google_project.platform_eng.project_id}.svc.id.goog"
  }
}

resource "google_gke_hub_membership" "platform_eng_cluster" {
  depends_on = [
    google_project_service.platform_eng_gkeconnect_googleapis_com,
    google_project_service.platform_eng_gkehub_googleapis_com
  ]

  membership_id = google_container_cluster.platform_eng.name
  project       = data.google_project.platform_eng.project_id

  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.platform_eng.id}"
    }
  }
}

provider "kubernetes" {
  host  = local.platform_eng_connect_gateway_host_url
  token = data.google_client_config.default.access_token
}
