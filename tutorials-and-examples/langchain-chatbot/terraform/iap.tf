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

module "iap_auth" {
  source = "../../../modules/iap"

  project_id               = var.project_id
  namespace                = var.k8s_namespace
  support_email            = var.support_email
  app_name                 = var.app_name
  create_brand             = var.create_brand
  k8s_ingress_name         = var.k8s_ingress_name
  k8s_managed_cert_name    = var.k8s_managed_cert_name
  k8s_iap_secret_name      = var.k8s_iap_secret_name
  k8s_backend_config_name  = var.k8s_backend_config_name
  k8s_backend_service_name = var.k8s_app_service_name
  k8s_backend_service_port = var.k8s_app_service_port
  client_id                = var.oauth_client_id
  client_secret            = var.oauth_client_secret
  domain                   = var.domain
  members_allowlist        = var.members_allowlist

  depends_on = [
    kubernetes_deployment.app,
    kubernetes_service.app
  ]
}
