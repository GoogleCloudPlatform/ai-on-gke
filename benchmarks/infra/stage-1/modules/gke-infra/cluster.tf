/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  _cluster_sa = (
    local.cluster_create
    ? module.cluster-service-account.0.email
    : data.google_container_cluster.cluster.0.node_config.0.service_account
  )
  cluster_sa = (
    local._cluster_sa == "default"
    ? module.project.service_accounts.default.compute
    : local._cluster_sa
  )
  cluster_sa_roles = [
    "roles/artifactregistry.reader",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer"
  ]
  cluster_vpc = (
    local.use_shared_vpc || !local.vpc_create
    # cluster variable configures networking
    ? {
      network = try(
        var.cluster_create.vpc.id, null
      )
      secondary_range_names = try(
        var.cluster_create.vpc.secondary_range_names, null
      )
      subnet = try(
        var.cluster_create.vpc.subnet_id, null
      )
    }
    # VPC creation configures networking
    : {
      network               = module.vpc.0.id
      secondary_range_names = { pods = "pods", services = "services" }
      subnet                = values(module.vpc.0.subnet_ids)[0]
    }
  )
}

data "google_container_cluster" "cluster" {
  count    = !local.cluster_create ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = var.cluster_name
}

module "cluster-service-account" {
  source     = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/iam-service-account?ref=v30.0.0&depth=1"
  count      = local.cluster_create ? 1 : 0
  project_id = module.project.project_id
  name       = var.prefix
}

module "cluster-standard" {
  source              = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/gke-cluster-standard?ref=v30.0.0&depth=1"
  count               = local.cluster_create && !var.gke_autopilot ? 1 : 0
  project_id          = module.project.project_id
  name                = var.cluster_name
  location            = var.gke_location
  min_master_version  = var.cluster_create.version
  deletion_protection = false
  vpc_config = {
    network                  = local.cluster_vpc.network
    subnetwork               = local.cluster_vpc.subnet
    secondary_range_names    = local.cluster_vpc.secondary_range_names
    master_authorized_ranges = var.cluster_create.master_authorized_ranges
    master_ipv4_cidr_block   = var.cluster_create.master_ipv4_cidr_block
  }
  private_cluster_config = var.private_cluster_config == null ? null : merge(var.private_cluster_config, {
    enable_private_endpoint = var.enable_private_endpoint
  })
  labels          = var.cluster_create.labels
  release_channel = var.cluster_create.options.release_channel
  backup_configs = {
    enable_backup_agent = var.cluster_create.options.enable_backup_agent
  }
  enable_features = {
    dns = {
      provider = "CLOUD_DNS"
      scope    = "CLUSTER_SCOPE"
      domain   = "cluster.local"
    }
    cost_management = true
    gateway_api     = true
  }
  enable_addons = {
    dns_cache                      = var.cluster_create.options.dns_cache
    gce_persistent_disk_csi_driver = var.cluster_create.options.enable_gce_persistent_disk_csi_driver
    gcp_filestore_csi_driver       = var.cluster_create.options.enable_gcp_filestore_csi_driver
    gcs_fuse_csi_driver            = var.cluster_create.options.enable_gcs_fuse_csi_driver
  }
  monitoring_config = {
    enable_api_server_metrics         = true
    enable_controller_manager_metrics = true
    enable_scheduler_metrics          = true
  }
  logging_config = {
    enable_api_server_logs         = true
    enable_scheduler_logs          = true
    enable_controller_manager_logs = true
  }
  maintenance_config = {
    daily_window_start_time = "01:00"
  }
}

module "cluster-autopilot" {
  source              = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/gke-cluster-autopilot?ref=v30.0.0&depth=1"
  count               = local.cluster_create && var.gke_autopilot ? 1 : 0
  project_id          = module.project.project_id
  name                = var.cluster_name
  location            = var.gke_location
  node_locations      = var.node_locations
  min_master_version  = var.cluster_create.version
  deletion_protection = false
  vpc_config = {
    network                  = local.cluster_vpc.network
    subnetwork               = local.cluster_vpc.subnet
    secondary_range_names    = local.cluster_vpc.secondary_range_names
    master_authorized_ranges = var.cluster_create.master_authorized_ranges
    master_ipv4_cidr_block   = var.cluster_create.master_ipv4_cidr_block
  }
  private_cluster_config = var.private_cluster_config == null ? null : merge(var.private_cluster_config, {
    enable_private_endpoint = var.enable_private_endpoint
  })
  labels          = var.cluster_create.labels
  release_channel = var.cluster_create.options.release_channel
  backup_configs = {
    enable_backup_agent = var.cluster_create.options.enable_backup_agent
  }
  enable_features = {
    dns = {
      provider = "CLOUD_DNS"
      scope    = "CLUSTER_SCOPE"
      domain   = "cluster.local"
    }
    cost_management = true
    gateway_api     = true
  }
  # GCS, Filestore, Persistent Disk CSI drivers and NodeLocal DNSCache are enabled by default 
  monitoring_config = {
    enable_api_server_metrics         = true
    enable_controller_manager_metrics = true
    enable_scheduler_metrics          = true
  }
  logging_config = {
    enable_api_server_logs         = true
    enable_scheduler_logs          = true
    enable_controller_manager_logs = true
  }
  maintenance_config = {
    daily_window_start_time = "01:00"
  }
}

module "cluster-nodepool" {
  source     = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/gke-nodepool?ref=v30.0.0&depth=1"
  depends_on = [module.cluster-standard]
  for_each   = (local.cluster_create && !var.gke_autopilot) ? var.nodepools : tomap({})

  project_id   = module.project.project_id
  cluster_name = var.cluster_name
  name         = "${var.cluster_name}-${each.key}"
  location     = var.gke_location
  service_account = {
    email        = module.cluster-service-account.0.email
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  node_config = {
    machine_type = each.value.machine_type
    spot         = each.value.spot
    shielded_instance_config = {
      enable_integrity_monitoring = true
      enable_secure_boot          = true
    }
    gvnic       = true
    gke_version = each.value.gke_version

    guest_accelerator = each.value.guest_accelerator == null ? null : {
      type  = each.value.guest_accelerator.type
      count = each.value.guest_accelerator.count

      gpu_driver = each.value.guest_accelerator.gpu_driver == null ? null : {
        version                    = each.value.guest_accelerator.gpu_driver.version
        partition_size             = each.value.guest_accelerator.gpu_driver.partition_size
        max_shared_clients_per_gpu = each.value.guest_accelerator.gpu_driver.max_shared_clients_per_gpu
      }
    }

    ephemeral_ssd_count = each.value.ephemeral_ssd_block_config == null ? null : each.value.ephemeral_ssd_block_config.ephemeral_ssd_count

    local_nvme_ssd_count = each.value.local_nvme_ssd_block_config == null ? null : each.value.local_nvme_ssd_block_config.local_ssd_count

    image_type = "cos_containerd"

    /*workload_metadata_config {
      mode = "GKE_METADATA"
    }*/
  }
  nodepool_config = {
    autoscaling = {
      max_node_count = each.value.max_node_count
      min_node_count = each.value.min_node_count
    }
    management = {
      auto_repair  = true
      auto_upgrade = true
    }
  }
}


/* TDOO - enable testing  

check "cluster_networking" {
  assert {
    condition = (
      local.use_shared_vpc
      ? (
        try(var.cluster_create.vpc.id, null) != null &&
        try(var.cluster_create.vpc.subnet_id, null) != null
      )
      : true
    )
    error_message = "Cluster network and subnetwork are required in shared VPC mode."
  }
}
*/
