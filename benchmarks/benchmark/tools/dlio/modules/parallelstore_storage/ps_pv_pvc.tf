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

resource "local_file" "ps_pv" {
  content = templatefile("${path.module}/ps_pv.tpl", {
    pv_name          = "${var.pv_name}"
    pvc_name         = "${var.pvc_name}"
    project          = "${var.project}"
    ps_location      = "${var.location}"
    ps_instance_name = "${var.ps_instance_name}"
    ps_ip_address_1  = "${var.ps_ip_address_1}"
    ps_ip_address_2  = "${var.ps_ip_address_2}"
    ps_ip_address_3  = "${var.ps_ip_address_3}"
    ps_network_name  = "${var.ps_network_name}"
  })
  filename = "${path.module}/pv-spec-rendered.yaml"
}

resource "kubectl_manifest" "ps_pv" {
  count     = var.storageclass == "" ? 1 : 0
  yaml_body = resource.local_file.ps_pv.content
}

resource "local_file" "ps_pvc" {
  content = templatefile("${path.module}/ps_pvc.tpl", {
    pv_name      = var.storageclass == "" ? "${var.pv_name}" : ""
    namespace    = "${var.namespace}"
    pvc_name     = "${var.pvc_name}"
    storageclass = "${var.storageclass}"
  })
  filename = "${path.module}/pvc-spec-rendered.yaml"
}

resource "kubectl_manifest" "ps_pvc" {
  yaml_body = resource.local_file.ps_pvc.content
}

resource "local_file" "dataloader" {
  content = templatefile("${path.module}/dataloader_job.tpl", {
    namespace       = "${var.namespace}"
    pvc_name        = "${var.pvc_name}"
    gcs_bucket      = "${var.gcs_bucket}"
    service_account = "${var.k8s_service_account}"
  })
  filename = "${path.module}/dataloader-job-rendered.yaml"
}

resource "kubectl_manifest" "dataloader" {
  count     = var.run_parallelstore_data_loader == "\"true\"" ? 1 : 0
  yaml_body = resource.local_file.dataloader.content
}
