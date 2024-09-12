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

data "google_container_cluster" "nim_llm" {
  name     = var.cluster_name
  location = var.cluster_location
}

data "google_client_config" "current" {

}

data "kubernetes_service" "nim_svc" {
  metadata {
    name = "nim-nim-llm"
  }
}

resource "kubernetes_namespace" "nim" {
  metadata {
    name = var.kubernetes_namespace
  }
}

resource "kubernetes_secret" "ngc_secret" {
  metadata {
    name      = "ngc-secret"
    namespace = kubernetes_namespace.nim.metadata.0.name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      "auths" = {
        "nvcr.io" = {
          "username" = "$oauthtoken"
          "password" = var.ngc_api_key
          "auth"     = base64encode("$oauthtoken:${var.ngc_api_key}")
        }
      }
    })
  }

  depends_on = [kubernetes_namespace.nim]
}

resource "kubernetes_secret" "ngc_api" {
  metadata {
    name      = "ngc-api"
    namespace = kubernetes_namespace.nim.metadata.0.name
  }

  type = "Opaque"

  data = {
    NGC_API_KEY = var.ngc_api_key
  }

  depends_on = [kubernetes_namespace.nim]
}

resource "kubernetes_persistent_volume_claim" "pvc_nim" {
  metadata {
    generate_name = "pvc-nim-"
    namespace     = kubernetes_namespace.nim.metadata.0.name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "100Gi"
      }
    }
  }
  wait_until_bound = false
}

resource "helm_release" "nim_release" {
  name                = "nim"
  namespace           = kubernetes_namespace.nim.metadata.0.name
  chart               = "https://helm.ngc.nvidia.com/nim/charts/nim-llm-${var.chart_version}.tgz"
  repository_username = "$oauthtoken"
  repository_password = var.ngc_api_key

  set {
    name  = "image.repository"
    value = "nvcr.io/nim/${var.image_name}"
  }

  set {
    name  = "image.tag"
    value = var.image_tag
  }

  set {
    name  = "model.name"
    value = var.image_name
  }

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "resources.limits.nvidia\\.com/gpu"
    value = var.gpu_limits
  }

  set {
    name  = "persistence.enabled"
    value = true
  }

  set {
    name  = "persistence.existingClaim"
    value = kubernetes_persistent_volume_claim.pvc_nim.metadata.0.name
  }

  depends_on = [kubernetes_namespace.nim]
}
