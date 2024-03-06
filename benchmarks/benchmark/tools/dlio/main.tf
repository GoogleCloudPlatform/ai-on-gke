# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

data "google_client_config" "provider" {}

provider "kubectl" {
  config_path = pathexpand("~/.kube/config")
}

module "gcs_pv_pvc" {
  source = "./modules/storage"
  count  = var.run_with_gcs_fuse_csi == "\"true\"" ? 1 : 0

  namespace                   = var.namespace
  pv_name                     = var.pv_name
  gcsfuse_stat_cache_capacity = var.gcsfuse_stat_cache_capacity
  gcsfuse_stat_cache_ttl      = var.gcsfuse_stat_cache_ttl
  gcsfuse_type_cache_ttl      = var.gcsfuse_type_cache_ttl
  pvc_name                    = var.pvc_name
  gcs_bucket                  = var.gcs_bucket
}

module "ps_storage" {
  source = "./modules/parallelstore_storage"
  count  = var.run_with_parallelstore_csi == "\"true\"" ? 1 : 0

  pv_name                       = var.pv_name
  pvc_name                      = var.pvc_name
  gcs_bucket                    = var.gcs_bucket
  ps_instance_name              = var.parallelstore_instance_name
  ps_ip_address_1               = var.parallelstore_ip_address_1
  ps_ip_address_2               = var.parallelstore_ip_address_2
  ps_ip_address_3               = var.parallelstore_ip_address_3
  ps_network_name               = var.parallelstore_network_name
  location                      = var.parallelstore_location
  storageclass                  = var.parallelstore_storageclass
  project                       = var.parallelstore_project
  k8s_service_account           = var.k8s_service_account
  run_parallelstore_data_loader = var.run_parallelstore_data_loader
  namespace                     = var.namespace
}

module "dlio" {
  source = "./modules/dlio"

  depends_on                               = [module.gcs_pv_pvc]
  namespace                                = var.namespace
  job_backoffLimit                         = var.job_backoffLimit
  job_completions                          = var.job_completions
  job_parallelism                          = var.job_parallelism
  gcs_fuse_csi_driver_enabled              = var.run_with_gcs_fuse_csi
  gcs_fuse_sidecar_cpu_limit               = var.gcs_fuse_sidecar_cpu_limit
  gcs_fuse_sidecar_memory_limit            = var.gcs_fuse_sidecar_memory_limit
  gcs_fuse_sidecar_ephemeral_storage_limit = var.gcs_fuse_sidecar_ephemeral_storage_limit
  pscsi_driver_enabled                     = var.run_with_parallelstore_csi
  pscsi_sidecar_cpu_limit                  = var.pscsi_sidecar_cpu_limit
  pscsi_sidecar_memory_limit               = var.pscsi_sidecar_memory_limit
  dlio_container_cpu_limit                 = var.dlio_container_cpu_limit
  dlio_container_memory_limit              = var.dlio_container_memory_limit
  dlio_container_ephemeral_storage         = var.dlio_container_ephemeral_storage
  dlio_generate_data                       = var.dlio_generate_data
  dlio_number_of_processors                = var.dlio_number_of_processors
  dlio_data_mount_path                     = var.dlio_data_mount_path
  dlio_benchmark_result                    = var.dlio_benchmark_result
  dlio_model                               = var.dlio_model
  dlio_profiler                            = var.dlio_profiler
  dlio_record_length                       = var.dlio_record_length
  dlio_record_length_stdev                 = var.dlio_record_length_stdev
  dlio_record_length_resize                = var.dlio_record_length_resize
  dlio_number_of_files                     = var.dlio_number_of_files
  dlio_batch_size                          = var.dlio_batch_size
  dlio_train_epochs                        = var.dlio_train_epochs
  dlio_iostat_devices                      = var.dlio_iostat_devices
  dlio_read_threads                        = var.dlio_read_threads
  gcs_bucket                               = var.gcs_bucket
  result_bucket                            = var.result_bucket
  k8s_service_account                      = var.k8s_service_account
  pvc_name                                 = var.pvc_name
}
