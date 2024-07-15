# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

resource "helm_release" "prometheus_adapter" {
  name       = "my-release"
  chart      = "prometheus-adapter"
  repository = "https://prometheus-community.github.io/helm-charts"
  values     = var.config_file != "" ? [var.config_file] : []
}

resource "kubernetes_deployment_v1" "frontend" {
  metadata {
    name = "frontend"
    labels = {
      "app" : "frontend"
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        "app" : "frontend"
      }
    }
    template {
      metadata {
        labels = {
          "app" : "frontend"
        }
      }
      spec {
        automount_service_account_token = true
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "kubernetes.io/arch"
                  operator = "In"
                  values = [
                    "arm64",
                    "amd64"
                  ]
                }
                match_expressions {
                  key      = "kubernetes.io/os"
                  operator = "In"
                  values = [
                    "linux"
                  ]
                }
              }
            }
          }
        }
        container {
          name  = "frontend"
          image = "gke.gcr.io/prometheus-engine/frontend:v0.8.0-gke.4"
          args = [
            "--web.listen-address=:9090",
            format("--query.project-id=%s", var.project_id)
          ]
          port {
            name           = "web"
            container_port = 9090
          }
          readiness_probe {
            http_get {
              path = "/-/ready"
              port = "web"
            }
          }
          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["all"]
            }
            privileged      = false
            run_as_group    = 1000
            run_as_non_root = true
            run_as_user     = 1000
          }
          liveness_probe {
            http_get {
              path = "/-/healthy"
              port = "web"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "frontend-service" {
  metadata {
    name = "prometheus"
  }
  spec {
    cluster_ip = "None"
    selector = {
      "app" : "frontend"
    }
    port {
      name = "web"
      port = 9090
    }

  }
}