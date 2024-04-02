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
  csi_driver_templates = [
    for f in fileset(local.csi_driver_templates_path, "*yaml") :
    "${local.csi_driver_templates_path}/${f}"
  ]
  csi_driver_templates_path = "${path.module}/csi-driver"

  all_driver_manifests = flatten([for manifest_file in local.csi_driver_templates :
    [for data in split("---", templatefile(manifest_file, {})) : data]
  ])

  gcp_csi_driver_plugin_path = "${path.module}/csi-driver-gcp-plugin"

  gcp_plugin_templates = [
    for f in fileset(local.gcp_csi_driver_plugin_path, "*yaml") :
    "${local.gcp_csi_driver_plugin_path}/${f}"
  ]

  all_plugin_manifests = flatten([for manifest_file in local.gcp_plugin_templates :
    [for data in split("---", templatefile(manifest_file, {})) : data]
  ])
}

module "secret-manager" {
  source     = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/secret-manager?ref=v30.0.0&depth=1"
  project_id = var.project_id
  secrets = {
    "${var.secret_name}" = {
      locations = [var.secret_location]
    }
  }
  iam = {
    "${var.secret_name}" = {
      "roles/secretmanager.secretAccessor" = ["serviceAccount:${var.google_service_account}@${var.project_id}.iam.gserviceaccount.com"]
    }
  }
}

resource "kubernetes_manifest" "csi_driver" {
  for_each = (toset(compact(local.all_driver_manifests)))
  manifest = yamldecode(each.value)
  timeouts {
    create = "30m"
  }
}

resource "kubernetes_manifest" "gcp_plugin" {
  for_each = (toset(compact(local.all_plugin_manifests)))
  manifest = yamldecode(each.value)
  timeouts {
    create = "30m"
  }
  depends_on      = [resource.kubernetes_manifest.csi_driver]
  computed_fields = ["spec.template.spec.containers[0].volumeMounts[0].readOnly", "spec.template.spec.hostIPC", "spec.template.spec.hostPID", "spec.template.spec.hostNetwork"]
}