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


module "slurm_nodepool_sa" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account?ref=v33.0.0"
  project_id = module.project.project_id
  name       = "slurm-nodepool-sa"
  # non-authoritative roles granted *to* the service accounts on other resources
  iam_project_roles = {
    "${module.project.project_id}" = [
      "roles/monitoring.metricWriter",
      "roles/logging.logWriter",
      "roles/artifactregistry.reader",
    ]
  }
}

module "cluster-1-nodepool-2" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gke-nodepool?ref=v33.0.0"
  project_id   = module.project.project_id
  cluster_name = module.cluster-1.name
  location     = var.region
  name         = "slurm-001"
  service_account = {
    create = false
    email  = module.slurm_nodepool_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  node_locations = ["${var.region}-b"]
  node_config = {
    machine_type = "n1-standard-8"
    disk_size_gb = 100
    disk_type    = "pd-ssd"
    gvnic        = true
    spot         = false
    guest_accelerator = {
      type  = "nvidia-tesla-t4"
      count = 2
      gpu_driver = {
        version = "DEFAULT"
      }
    }
  }

  nodepool_config = {
    autoscaling = {
      max_node_count = 10
      min_node_count = 1
    }
    management = {
      auto_repair  = true
      auto_upgrade = true
    }
  }
}

module "cluster-1-nodepool-3" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gke-nodepool?ref=v33.0.0"
  project_id   = module.project.project_id
  cluster_name = module.cluster-1.name
  location     = var.region
  name         = "slurm-002"
  service_account = {
    create = false
    email  = module.slurm_nodepool_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  node_locations = ["${var.region}-b"]
  node_config = {
    machine_type = "g2-standard-4"
    disk_size_gb = 100
    disk_type    = "pd-ssd"
    gvnic        = true
    spot         = false
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
