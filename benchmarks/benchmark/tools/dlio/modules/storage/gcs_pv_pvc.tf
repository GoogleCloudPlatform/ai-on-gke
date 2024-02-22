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

resource "local_file" "pv_podspec" {
  content = templatefile("${path.module}/pv_podspec.tpl", {
    namespace                   = "${var.namespace}"
    pv_name                     = "${var.pv_name}"
    pvc_name                    = "${var.pvc_name}"
    gcsfuse_stat_cache_capacity = "${var.gcsfuse_stat_cache_capacity}"
    gcsfuse_stat_cache_ttl      = "${var.gcsfuse_stat_cache_ttl}"
    gcsfuse_type_cache_ttl      = "${var.gcsfuse_type_cache_ttl}"
    gcs_bucket                  = "${var.gcs_bucket}"
  })
  filename = "${path.module}/pv-pod-spec-rendered.yaml"
}

resource "kubectl_manifest" "pv_podspec" {
  yaml_body = resource.local_file.pv_podspec.content
}

resource "local_file" "pvc_podspec" {
  content = templatefile("${path.module}/pvc_podspec.tpl", {
    namespace  = "${var.namespace}"
    pv_name    = "${var.pv_name}"
    pvc_name   = "${var.pvc_name}"
    gcs_bucket = "${var.gcs_bucket}"
  })
  filename = "${path.module}/pvc-pod-spec-rendered.yaml"
}

resource "kubectl_manifest" "pvc_podspec" {
  yaml_body = resource.local_file.pvc_podspec.content
}