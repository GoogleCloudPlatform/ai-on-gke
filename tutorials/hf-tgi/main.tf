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

resource "kubernetes_service" "inference_service" {
  metadata {
    name = "mistral-7b-instruct-service"
    labels = {
      app = "mistral-7b-instruct"
    }
    namespace = var.namespace
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
      "cloud.google.com/neg"                = "{\"ingress\":true}"
    }
  }
  spec {
    selector = {
      app = "mistral-7b-instruct"
    }
    session_affinity = "ClientIP"
    port {
      protocol    = "TCP"
      port        = 80
      target_port = 8080
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_deployment" "inference_deployment" {
  metadata {
    name      = "mistral-7b-instruct"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mistral-7b-instruct"
      }
    }

    template {
      metadata {
        labels = {
          app = "mistral-7b-instruct"
        }
      }

      spec {
        container {
          image = "ghcr.io/huggingface/text-generation-inference:1.1.0"
          name  = "mistral-7b-instruct"

          port {
            name           = "metrics"
            container_port = 8080
            protocol       = "TCP"
          }

          env {
            name  = "MODEL_ID"
            value = "mistralai/Mistral-7B-Instruct-v0.1"
          }

          env {
            name  = "NUM_SHARD"
            value = "2"
          }

          env {
            name  = "PORT"
            value = "8080"
          }

          resources {
            limits = {
              "nvidia.com/gpu" = "2"
            }
            requests = {
              # Sufficient storage to fit the Mistral-7B-Instruct-v0.1 model
              "ephemeral-storage" = "20Gi"
              "nvidia.com/gpu"    = "2"
            }
          }

          volume_mount {
            mount_path = "/dev/shm"
            name       = "dshm"
          }

          volume_mount {
            mount_path = "/data"
            name       = "data"
          }

          #liveness_probe {
          #http_get {
          #path = "/"
          #port = 8080

          #http_header {
          #name  = "X-Custom-Header"
          #value = "Awesome"
          #}
          #}

          #initial_delay_seconds = 3
          #period_seconds        = 3
          #}
        }

        volume {
          name = "dshm"
          empty_dir {
            medium = "Memory"
          }
        }

        volume {
          name = "data"
          empty_dir {}
        }

        node_selector = merge({
          "cloud.google.com/gke-accelerator" = "nvidia-l4"
          }, var.autopilot_cluster ? {
          "cloud.google.com/gke-ephemeral-storage-local-ssd" = "true"
          "cloud.google.com/compute-class"                   = "Accelerator"
        } : {})
      }
    }
  }
}
