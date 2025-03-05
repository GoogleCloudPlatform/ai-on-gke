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


resource "kubernetes_namespace" "argo" {
  provider = kubernetes.metaflow
  metadata {
    name = "argo"
  }
  depends_on = [module.gke_cluster]
}

module "argo_executor_workload_identity" {
  providers = {
    kubernetes = kubernetes.metaflow
  }
  source                          = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  name                            = var.metaflow_argo_workflows_sa_name
  automount_service_account_token = true
  namespace                       = "argo"
  roles                           = ["roles/storage.objectUser"]
  project_id                      = var.project_id
  depends_on                      = [kubernetes_namespace.argo]
}

resource "kubernetes_role_binding" "add_executer_role_to_sa" {
  provider = kubernetes.metaflow
  metadata {
    name      = "executor-sa"
    namespace = "argo"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "executor"
  }
  subject {
    kind      = "ServiceAccount"
    name      = var.metaflow_argo_workflows_sa_name
    namespace = "argo"
  }
  depends_on = [module.argo_executor_workload_identity]
}

data "http" "argo_workflows_manifest" {
  url = "https://github.com/argoproj/argo-workflows/releases/download/v3.6.2/quick-start-minimal.yaml"
}

data "kubectl_file_documents" "docs" {
  content = data.http.argo_workflows_manifest.response_body

}

resource "kubectl_manifest" "argo_workflows" {
  provider           = kubectl.metaflow
  override_namespace = "argo"
  for_each           = data.kubectl_file_documents.docs.manifests
  yaml_body          = each.value
  depends_on         = [kubernetes_namespace.argo, module.argo_executor_workload_identity]
}
