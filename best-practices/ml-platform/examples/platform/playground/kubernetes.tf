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
  # https://github.com/hashicorp/terraform-provider-google/issues/13325
  connect_gateway_host_url = "https://connectgateway.googleapis.com/v1/projects/${data.google_project.environment.number}/locations/global/gkeMemberships/${google_container_cluster.mlp.name}"
  kubeconfig_dir           = abspath("${path.module}/kubeconfig")
}

provider "kubernetes" {
  host  = local.connect_gateway_host_url
  token = data.google_client_config.default.access_token
}

resource "null_resource" "connect_gateway_kubeconfig" {
  provisioner "local-exec" {
    command     = <<EOT
KUBECONFIG="${self.triggers.project_id}_${self.triggers.membership_id}" \
gcloud container fleet memberships get-credentials ${self.triggers.membership_id} \
--project ${self.triggers.project_id}
    EOT
    interpreter = ["bash", "-c"]
    working_dir = self.triggers.kubeconfig_dir
  }

  provisioner "local-exec" {
    command     = "rm -f ${self.triggers.project_id}_${self.triggers.membership_id}"
    when        = destroy
    interpreter = ["bash", "-c"]
    working_dir = self.triggers.kubeconfig_dir
  }

  triggers = {
    kubeconfig_dir = local.kubeconfig_dir
    membership_id  = google_gke_hub_membership.cluster.membership_id
    project_id     = data.google_project.environment.project_id
  }
}

data "kubernetes_namespace_v1" "team" {
  depends_on = [
    null_resource.git_cred_secret_ns,
    null_resource.namespace_manifests
  ]

  metadata {
    name = var.namespace
  }
}
