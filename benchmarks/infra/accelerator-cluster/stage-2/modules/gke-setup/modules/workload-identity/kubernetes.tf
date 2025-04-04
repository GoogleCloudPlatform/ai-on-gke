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
  wi_sa_email = (
    var.google_service_account_create
    ? module.workload-service-account.0.email
    : data.google_service_account.gsa.0.email
  )
  wi_sa_name = (
    var.google_service_account_create
    ? module.workload-service-account.0.name
    : data.google_service_account.gsa.0.name
  )
}

resource "kubernetes_namespace" "namespace" {
  count = var.namespace_create ? 1 : 0
  metadata {
    annotations = {
      name = var.namespace
    }
    name = var.namespace
  }
}

resource "kubernetes_service_account" "ksa" {
  metadata {
    name      = var.kubernetes_service_account
    namespace = var.namespace
    annotations = {
      "iam.gke.io/gcp-service-account" = "${local.wi_sa_email}"
    }
  }
  depends_on = [module.workload-service-account,
    kubernetes_namespace.namespace
  ]
}
