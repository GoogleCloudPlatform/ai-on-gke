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

resource "kubernetes_deployment" "app" {
  metadata {
    name      = var.k8s_app_deployment_name
    namespace = var.k8s_namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "chat"
      }
    }
    template {
      metadata {
        labels = {
          app = "chat"
        }
      }
      spec {
        container {
          name              = "app"
          image             = var.k8s_app_image
          image_pull_policy = "Always"
          env {
            name  = "MODEL_BASE_URL"
            value = var.model_base_url
          }
          env {
            name  = "MODEL_NAME"
            value = var.model_name
          }
          env {
            name  = "DB_URI"
            value = "postgresql://postgres:${random_password.db_password.result}@${google_sql_database_instance.langchain_storage.private_ip_address}/${var.db_name}"
          }
          port {
            container_port = 8501
          }
          liveness_probe {
            http_get {
              path   = "/_stcore/health"
              port   = 8501
              scheme = "HTTP"
            }
            timeout_seconds = 1
            period_seconds  = 10
          }
          readiness_probe {
            http_get {
              path   = "/_stcore/health"
              port   = 8501
              scheme = "HTTP"
            }
            timeout_seconds = 1
            period_seconds  = 10
          }
          resources {
            limits = {
              cpu               = "1"
              ephemeral-storage = "1Gi"
              memory            = "2Gi"
            }
            requests = {
              cpu               = "200m"
              ephemeral-storage = "1Gi"
              memory            = "1Gi"
            }
          }
          security_context {
            allow_privilege_escalation = false
            privileged                 = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            run_as_user                = 1000

            capabilities {
              drop = ["ALL"]
            }
          }
        }

        security_context {
          run_as_non_root     = true
          supplemental_groups = []
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      spec[0].template[0].spec[0].toleration,
      spec[0].template[0].spec[0].security_context[0].seccomp_profile,
    ]
  }
}

resource "kubernetes_service" "app" {
  metadata {
    name      = "chat"
    namespace = var.k8s_namespace
  }
  spec {
    selector = {
      app = "chat"
    }
    port {
      protocol    = "TCP"
      port        = 80
      target_port = 8501
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations
    ]
  }
}
