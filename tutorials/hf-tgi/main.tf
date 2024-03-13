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
    name = "gemma-7b-it-service"
    labels = {
      app="gemma-7b-it"
    }
    namespace = var.namespace
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
      "cloud.google.com/neg"                = "{\"ingress\":true}"
    }
  }
  spec {
    selector = {
      app = "gemma-7b-it"
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
    name      = "gemma-7b-it"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "gemma-7b-it"
      }
    }

    template {
      metadata {
        labels = {
          app = "gemma-7b-it"
        }
      }

      spec {
        container {
          image = "ghcr.io/huggingface/text-generation-inference:1.4.2"
          name  = "gemma-7b-it"

          port {
            name           = "metrics"
            container_port = 8080
            protocol       = "TCP"
          }

          env {
            name  = "MODEL_ID"
            value = "google/gemma-7b-it"
          }

          env {
            name  = "NUM_SHARD"
            value = "2"
          }

          env {
            name  = "PORT"
            value = "8080"
          }

          env {
            name  = "HUGGING_FACE_HUB_TOKEN"
            value_from {
              secret_key_ref {
                name = var.hf_secret
                key  = "HF_TOKEN"
              }
            }
          }

          resources {
            limits = {
              "nvidia.com/gpu" = "2"
            }
            requests = {
              # Sufficient storage to fit the Gemma-7b-it model
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
