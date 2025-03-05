# Copyright 2025 Google LLC
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


module "metaflow_metadata_workload_identity" {
  providers = {
    kubernetes = kubernetes.metaflow
  }
  source     = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  name       = var.metaflow_kubernetes_service_account_name
  namespace  = var.metaflow_kubernetes_namespace
  roles      = [
    "roles/cloudsql.client",
    "roles/storage.objectUser",
  ]
  project_id = var.project_id
  depends_on = [module.gke_cluster]
}

resource "local_file" "metaflow-metadata-deployment-file" {
  content = templatefile(
    "${path.module}/../metaflow/templates/metaflow-metadata.yaml",
    {
      SERVICE_ACCOUNT_NAME = var.metaflow_kubernetes_service_account_name,
      CLOUDSQL_INSTANCE    = "${var.project_id}:${var.metaflow_cloudsql_instance_region}:${local.metaflow_cloudsql_instance}"
    }
  )
  filename = "${path.module}/../gen/metaflow-metadata.yaml"
}

resource "local_file" "metaflow-ui-deployment-file" {
  content = templatefile(
    "${path.module}/../metaflow/templates/metaflow-ui.yaml",
    {
      SERVICE_ACCOUNT_NAME = var.metaflow_kubernetes_service_account_name,
      CLOUDSQL_INSTANCE    = "${var.project_id}:${var.metaflow_cloudsql_instance_region}:${local.metaflow_cloudsql_instance}"
    }
  )
  filename = "${path.module}/../gen/metaflow-ui.yaml"
}
