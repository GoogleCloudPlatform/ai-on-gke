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

resource "kubernetes_deployment" "deployment_maxengine_server" {
  metadata {
    name = "maxengine-server"
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        App = "maxengine-server"
      }
    }
    template {
      metadata {
        labels = {
          App = "maxengine-server"
        }
      }
      spec {
        container {
          args = [
            "model_name=gemma-7b",
            "tokenizer_path=assets/tokenizer.gemma",
            "per_device_batch_size=4",
            "max_prefill_predict_length=1024",
            "max_target_length=2048",
            "async_checkpointing=false",
            "ici_fsdp_parallelism=1",
            "ici_autoregressive_parallelism=-1",
            "ici_tensor_parallelism=1",
            "scan_layers=false",
            "weight_dtype=bfloat16",
            format("load_parameters_path=gs://%s/final/unscanned/gemma_7b-it/0/checkpoints/0/items", var.bucket_name),
            "attention=dot_product",
            var.metrics_port != null ? format("prometheus_port=%d", var.metrics_port) : "",
          ]
          image             = "us-docker.pkg.dev/cloud-tpu-images/inference/maxengine-server:v0.2.2"
          image_pull_policy = "Always"
          name              = "maxengine-server"
          port {
            container_port = 9000
          }
          resources {
            limits = {
              "google.com/tpu" = 8
            }
            requests = {
              "google.com/tpu" = 8
            }
          }
          security_context {
            privileged = true
          }
        }
        container {
          image             = "us-docker.pkg.dev/cloud-tpu-images/inference/jetstream-http:v0.2.2"
          image_pull_policy = "Always"
          name              = "jetstream-http"
          port {
            container_port = 8000
          }
        }
        node_selector = {
          "cloud.google.com/gke-tpu-accelerator" = "tpu-v5-lite-podslice"
          "cloud.google.com/gke-tpu-topology"    = "2x4"
        }
      }
    }
  }
}

resource "kubernetes_service" "service_jetstream_svc" {
  metadata {
    name = "jetstream-svc"
  }
  spec {
    port {
      name        = "jetstream-http"
      port        = 8000
      protocol    = "TCP"
      target_port = 8000
    }
    port {
      name        = "jetstream-grpc"
      port        = 9000
      protocol    = "TCP"
      target_port = 9000
    }
    selector = {
      App = "maxengine-server"
    }
  }
}