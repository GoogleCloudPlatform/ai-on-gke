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

module "project" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/project?ref=v33.0.0"
  billing_account = var.billing_account_id
  name            = var.project_id
  parent          = var.folder_id
  services = [
    "compute.googleapis.com",
    "stackdriver.googleapis.com",
    "container.googleapis.com",
    "file.googleapis.com",
    "servicenetworking.googleapis.com"
  ]
}

module "vpc" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc?ref=v33.0.0"
  project_id = module.project.project_id
  name       = "default"
  subnets = [
    {
      ip_cidr_range = "10.0.0.0/24"
      name          = "subnet-1"
      region        = var.region
      secondary_ip_ranges = {
        pods     = "172.16.0.0/20"
        services = "192.168.0.0/24"
      }
    },
    {
      ip_cidr_range = "10.10.0.0/24"
      name          = "subnet-lb-1"
      region        = var.region
    }
  ]
  subnets_proxy_only = [
    {
      ip_cidr_range = "10.0.1.0/24"
      name          = "regional-proxy"
      region        = var.region
      active        = true
    }
  ]
}



module "firewall" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall?ref=v33.0.0"
  project_id = module.project.project_id
  network    = module.vpc.network.name
  default_rules_config = {
    admin_ranges = ["10.0.0.0/8"]
  }
  ingress_rules = {
    # implicit allow action
    allow-ingress-ssh = {
      description   = "Allow SSH from IAP"
      source_ranges = ["35.235.240.0/20"]
      rules         = [{ protocol = "tcp", ports = [22] }]
    }
  }
}

module "nat" {
  source         = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v33.0.0"
  project_id     = module.project.project_id
  region         = var.region
  name           = "default"
  router_network = module.vpc.network.self_link
}

module "docker_artifact_registry" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/artifact-registry?ref=v33.0.0"
  project_id = module.project.project_id
  location   = var.region
  name       = "slurm"
  format     = { docker = { standard = {} } }
}

module "cluster_nodepool_sa" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v33.0.0"
  project_id = module.project.project_id
  name       = "cluster-nodepool-sa"
  iam_project_roles = {
    "${module.project.project_id}" = [
      "roles/monitoring.metricWriter",
      "roles/logging.logWriter",
      "roles/artifactregistry.reader",
    ]
  }
}


module "cluster-1" {
  source              = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gke-cluster-standard?ref=v33.0.0"
  project_id          = module.project.project_id
  name                = "cluster-1"
  location            = var.region
  release_channel     = "RAPID"
  deletion_protection = false
  vpc_config = {
    network    = module.vpc.self_link
    subnetwork = module.vpc.subnets["${var.region}/subnet-1"].self_link
    secondary_range_names = {
      pods     = "pods"
      services = "services"
    }
    master_ipv4_cidr_block = "172.19.27.0/28"
  }
  enable_addons = {
    gce_persistent_disk_csi_driver = true
    http_load_balancing            = true
    horizontal_pod_autoscaling     = true
    gcp_filestore_csi_driver       = true
    gcs_fuse_csi_driver            = true
  }
  private_cluster_config = {
    enable_private_endpoint = false
    master_global_access    = true
  }
  enable_features = {
    dataplane_v2         = true
    workload_identity    = true
    image_streaming      = true
    intranode_visibility = true

    dns = {
      provider = "CLOUD_DNS"
      scope    = "CLUSTER_SCOPE"
    }
  }

  backup_configs = {
    enable_backup_agent = false
  }
  monitoring_config = {
    enable_api_server_metrics         = true
    enable_controller_manager_metrics = true
    enable_scheduler_metrics          = true
  }
  logging_config = {
    enable_workloads_logs = true
  }
}

module "cluster-1-nodepool-1" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gke-nodepool?ref=v33.0.0"
  project_id   = module.project.project_id
  cluster_name = module.cluster-1.name
  location     = var.region
  name         = "nodepool-1"
  service_account = {
    create = false
    email  = module.cluster_nodepool_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  node_config = {
    machine_type        = "n1-standard-8"
    disk_size_gb        = 100
    disk_type           = "pd-ssd"
    ephemeral_ssd_count = 1
    gvnic               = true
  }
  nodepool_config = {
    autoscaling = {
      max_node_count = 10
      min_node_count = 2
    }
    management = {
      auto_repair  = true
      auto_upgrade = true
    }
  }
}

