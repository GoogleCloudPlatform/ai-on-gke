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

module "gke-infra" {
  source       = "./modules/gke-infra/"
  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.region
  gke_location = var.gke_location

  cluster_create = {
    options = {
      enable_gcs_fuse_csi_driver            = var.cluster_options.enable_gcs_fuse_csi_driver
      enable_gcp_filestore_csi_driver       = var.cluster_options.enable_gcp_filestore_csi_driver
      enable_gce_persistent_disk_csi_driver = var.cluster_options.enable_gce_persistent_disk_csi_driver
    }
  }

  registry_create = true

  private_cluster_config  = var.private_cluster_config
  enable_private_endpoint = var.enable_private_endpoint

  vpc_create = var.vpc_create

  nodepools = var.nodepools

  filestore_storage = var.filestore_storage

  prefix = var.prefix
}
