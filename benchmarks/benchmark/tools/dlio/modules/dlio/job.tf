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

resource "local_file" "podspec" {
  content = templatefile("${path.module}/podspec.tpl", {
    namespace                                = "${var.namespace}"
    job_backoffLimit                         = "${var.job_backoffLimit}"
    job_completions                          = "${var.job_completions}"
    job_parallelism                          = "${var.job_parallelism}"
    gcs_fuse_csi_driver_enabled              = "${var.gcs_fuse_csi_driver_enabled}"
    gcs_fuse_sidecar_cpu_limit               = "${var.gcs_fuse_sidecar_cpu_limit}"
    gcs_fuse_sidecar_memory_limit            = "${var.gcs_fuse_sidecar_memory_limit}"
    gcs_fuse_sidecar_ephemeral_storage_limit = "${var.gcs_fuse_sidecar_ephemeral_storage_limit}"
    pscsi_driver_enabled                     = "${var.pscsi_driver_enabled}"
    pscsi_sidecar_cpu_limit                  = "${var.pscsi_sidecar_cpu_limit}"
    pscsi_sidecar_memory_limit               = "${var.pscsi_sidecar_memory_limit}"
    dlio_container_cpu_limit                 = "${var.dlio_container_cpu_limit}"
    dlio_container_memory_limit              = "${var.dlio_container_memory_limit}"
    dlio_container_ephemeral_storage         = "${var.dlio_container_ephemeral_storage}"
    dlio_generate_data                       = "${var.dlio_generate_data}"
    dlio_number_of_processors                = "${var.dlio_number_of_processors}"
    dlio_data_mount_path                     = "${var.dlio_data_mount_path}"
    dlio_benchmark_result                    = "${var.dlio_benchmark_result}"
    dlio_model                               = "${var.dlio_model}"
    dlio_profiler                            = "${var.dlio_profiler}"
    dlio_record_length                       = "${var.dlio_record_length}"
    dlio_record_length_stdev                 = "${var.dlio_record_length_stdev}"
    dlio_record_length_resize                = "${var.dlio_record_length_resize}"
    dlio_number_of_files                     = "${var.dlio_number_of_files}"
    dlio_batch_size                          = "${var.dlio_batch_size}"
    dlio_train_epochs                        = "${var.dlio_train_epochs}"
    dlio_iostat_devices                      = "${var.dlio_iostat_devices}"
    dlio_read_threads                        = "${var.dlio_read_threads}"
    gcs_bucket                               = "${var.gcs_bucket}"
    result_bucket                            = "${var.result_bucket}"
    service_account                          = "${var.k8s_service_account}"
    pvc_name                                 = "${var.pvc_name}"
  })
  filename = "${path.module}/pod-spec-rendered.yaml"
}

resource "kubectl_manifest" "podspec" {
  yaml_body = resource.local_file.podspec.content
}
