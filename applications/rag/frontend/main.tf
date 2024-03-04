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
data "google_project" "project" {
  project_id = var.project_id
}


data "kubernetes_service" "inference_service" {
  metadata {
    name      = var.inference_service_name
    namespace = var.inference_service_namespace
  }
}

data "kubernetes_secret" "db_secret" {
  metadata {
    name      = var.db_secret_name
    namespace = var.db_secret_namespace
  }
}

locals {
  instance_connection_name = format("%s:%s:%s", var.project_id, var.region, "pgvector-instance")
}

# IAP Section: Enabled the IAP service
resource "google_project_service" "project_service" {
  count   = var.add_auth ? 1 : 0
  project = var.project_id
  service = "iap.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

# IAP Section: Creates the OAuth client used in IAP
resource "google_iap_client" "iap_oauth_client" {
  count        = var.add_auth && var.client_id == "" ? 1 : 0
  display_name = "Frontend-Client"
  brand        = var.brand == "" ? "projects/${data.google_project.project.number}/brands/${data.google_project.project.number}" : var.brand
}

# IAP Section: Creates the GKE components
module "iap_auth" {
  count  = var.add_auth ? 1 : 0
  source = "../../../modules/iap"

  project_id                        = var.project_id
  namespace                         = var.namespace
  frontend_add_auth                 = var.add_auth
  frontend_k8s_ingress_name         = var.k8s_ingress_name
  frontend_k8s_managed_cert_name    = var.k8s_managed_cert_name
  frontend_k8s_iap_secret_name      = var.k8s_iap_secret_name
  frontend_k8s_backend_config_name  = var.k8s_backend_config_name
  frontend_k8s_backend_service_name = var.k8s_backend_service_name
  frontend_k8s_backend_service_port = var.k8s_backend_service_port
  frontend_client_id                = var.client_id != "" ? var.client_id : google_iap_client.iap_oauth_client[0].client_id
  frontend_client_secret            = var.client_id != "" ? var.client_secret : google_iap_client.iap_oauth_client[0].secret
  frontend_url_domain_addr          = var.url_domain_addr
  frontend_url_domain_name          = var.url_domain_name
  depends_on = [
    google_project_service.project_service,
    kubernetes_service.rag_frontend_service
  ]
}

module "frontend-workload-identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  use_existing_gcp_sa = !var.create_service_account
  name                = var.google_service_account
  namespace           = var.namespace
  project_id          = var.project_id
  roles               = ["roles/cloudsql.client", "roles/dlp.admin"]
}

resource "kubernetes_service" "rag_frontend_service" {
  metadata {
    name      = "rag-frontend"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "rag-frontend"
    }
    session_affinity = var.add_auth ? "None" : "ClientIP"
    port {
      port        = 8080
      target_port = 8080
    }

    type = var.add_auth ? "NodePort" : "ClientIP"
  }
}

resource "kubernetes_deployment" "rag_frontend_deployment" {
  metadata {
    name      = "rag-frontend"
    namespace = var.namespace
    labels = {
      app = "rag-frontend"
    }
  }

  spec {
    replicas = 3
    selector {
      match_labels = {
        app = "rag-frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "rag-frontend"
        }
      }

      spec {
        service_account_name = var.google_service_account
        container {
          image = "us-central1-docker.pkg.dev/ai-on-gke/rag-on-gke/frontend@sha256:e2dd85e92f42e3684455a316dee5f98f61f1f3fba80b9368bd6f48d5e2e3475e"
          name  = "rag-frontend"

          port {
            container_port = 8080
          }

          env {
            name  = "PROJECT_ID"
            value = "projects/${var.project_id}"
          }

          env {
            name  = "INSTANCE_CONNECTION_NAME"
            value = local.instance_connection_name
          }

          env {
            name  = "INFERENCE_ENDPOINT"
            value = data.kubernetes_service.inference_service.status.0.load_balancer.0.ingress.0.ip
          }

          env {
            name  = "TABLE_NAME"
            value = var.dataset_embeddings_table_name
          }

          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret.db_secret.metadata.0.name
                key  = "username"
              }
            }
          }

          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret.db_secret.metadata.0.name
                key  = "password"
              }
            }
          }

          env {
            name = "DB_NAME"
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret.db_secret.metadata.0.name
                key  = "database"
              }
            }
          }

          resources {
            limits = {
              cpu               = "3"
              memory            = "3Gi"
              ephemeral-storage = "5Gi"
            }
            requests = {
              cpu               = "3"
              memory            = "3Gi"
              ephemeral-storage = "5Gi"
            }
          }
        }

        container {
          image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.8.0"
          name  = "cloud-sql-proxy"

          args = [
            "--structured-logs",
            local.instance_connection_name,
          ]

          security_context {
            run_as_non_root = true
          }

          resources {
            limits = {
              cpu    = "1"
              memory = "2Gi"
            }
            requests = {
              cpu    = "1"
              memory = "2Gi"
            }
          }
        }
      }
    }
  }
}

data "kubernetes_service" "frontend-ingress" {
  metadata {
    name      = var.k8s_ingress_name
    namespace = var.namespace
  }
  depends_on = [module.iap_auth]
}

