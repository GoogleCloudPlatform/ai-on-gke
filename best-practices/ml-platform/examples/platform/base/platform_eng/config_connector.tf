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
  config_connector_sa_roles = [
    "roles/editor",
  ]
}

resource "google_service_account" "config_connector" {
  project      = data.google_project.platform_eng.project_id
  account_id   = "wi-config-connector"
  display_name = "Config Connector Service Account"
  description  = "Terraform-managed service account for Config Connector"
}

resource "google_project_iam_member" "config_connector_sa_roles" {
  for_each = toset(local.config_connector_sa_roles)
  project  = data.google_project.platform_eng.project_id
  member   = google_service_account.config_connector.member
  role     = each.value
}

resource "google_service_account_iam_member" "config_connector_wi" {
  member             = "serviceAccount:${data.google_project.platform_eng.project_id}.svc.id.goog[cnrm-system/cnrm-controller-manager]"
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.config_connector.name
}

data "google_storage_bucket_object" "configconnector_operator_bundle" {
  name   = "${var.platform_eng_configconnector_operator_version}/release-bundle.tar.gz"
  bucket = "configconnector-operator"
}

data "google_storage_bucket_object_content" "configconnector_operator_bundle" {
  name   = "${var.platform_eng_configconnector_operator_version}/release-bundle.tar.gz"
  bucket = "configconnector-operator"
}

resource "null_resource" "configconnector_operator_manifests" {
  provisioner "local-exec" {
    command     = <<EOT
mkdir -p ${self.triggers.configconnector_manifests_dir}
gsutil cp gs://configconnector-operator/${self.triggers.configconnector_operator_version}/release-bundle.tar.gz - | tar fvxz - --directory ${self.triggers.configconnector_manifests_dir}
EOT
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }

  provisioner "local-exec" {
    command     = "rm -rf ${self.triggers.configconnector_manifests_dir}"
    interpreter = ["bash", "-c"]
    when        = destroy
    working_dir = path.module
  }

  triggers = {
    configconnector_manifests_dir    = local.configconnector_manifests_dir
    configconnector_operator_version = var.platform_eng_configconnector_operator_version
  }
}

resource "kubernetes_manifest" "configconnector_operator" {
  for_each = { for manifest in provider::kubernetes::manifest_decode_multi(file("${local.configconnector_manifests_dir}/operator-system/autopilot-configconnector-operator.yaml")) : "${manifest.apiVersion}/${manifest.kind}/${manifest.metadata.name}" => manifest }
  manifest = each.value

  computed_fields = [
    "metadata.annotations",
    "metadata.creationTimestamp",
    "metadata.labels",
    "spec.template.spec.containers[0].resources"
  ]
}

resource "kubernetes_manifest" "config_connector_config" {
  manifest = {
    "apiVersion" = "core.cnrm.cloud.google.com/v1beta1"
    "kind"       = "ConfigConnector"
    "metadata" = {
      "name" = "configconnector.core.cnrm.cloud.google.com"
    }
    "spec" = {
      "googleServiceAccount" = "${google_service_account.config_connector.email}"
      "mode"                 = "cluster"
      "stateIntoSpec"        = "Absent"
    }
  }
}
