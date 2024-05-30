# Copyright 2023 Google LLC
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

resource "google_storage_bucket_iam_member" "gcs-bucket-iam" {
  bucket = var.gcs_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.google_service_account}@${var.project_id}.iam.gserviceaccount.com"
}

locals {
  security_context                  = { for k, v in var.security_context : k => v if v != null }
  cloudsql_instance_connection_name = format("%s:%s:%s", var.project_id, var.db_region, var.cloudsql_instance_name)
  additional_labels = tomap({
    for item in split(",", var.additional_labels) :
    split("=", item)[0] => split("=", item)[1]
  })
}

resource "helm_release" "ray-cluster" {
  name             = var.name
  repository       = "https://ray-project.github.io/kuberay-helm/"
  chart            = "ray-cluster"
  namespace        = var.namespace
  create_namespace = true
  version          = "1.0.0"

  values = [
    templatefile("${path.module}/values.yaml", {
      gcs_bucket                        = var.gcs_bucket
      k8s_service_account               = var.google_service_account
      additional_labels                 = local.additional_labels
      grafana_host                      = var.grafana_host
      security_context                  = local.security_context
      secret_name                       = var.db_secret_name
      cloudsql_instance_connection_name = local.cloudsql_instance_connection_name
      image                             = var.use_custom_image ? "us-central1-docker.pkg.dev/ai-on-gke/rag-on-gke/ray-image" : "rayproject/ray"
      image_tag                         = var.enable_gpu ? "2.9.3-py310-gpu" : var.use_custom_image ? "2.9.3-py310-gpu" : "2.9.3-py310"
      resource_requests = var.enable_gpu ? {
        "cpu"               = "8"
        "memory"            = "32G"
        "ephemeral-storage" = "20Gi"
        "nvidia.com/gpu"    = "1"
        } : {
        "cpu"               = "8"
        "memory"            = "32G"
        "ephemeral-storage" = "20Gi"
      }
      annotations = {
        "gke-gcsfuse/volumes" : "true"
        "gke-gcsfuse/cpu-limit" : "2"
        "gke-gcsfuse/memory-limit" : "8Gi"
        "gke-gcsfuse/ephemeral-storage-limit" : "20Gi"
      }
      node_selectors = var.autopilot_cluster ? var.enable_gpu ? {
        "cloud.google.com/compute-class" : "Accelerator"
        "cloud.google.com/gke-accelerator" : "nvidia-l4"
        "cloud.google.com/gke-ephemeral-storage-local-ssd" : "true"
        "iam.gke.io/gke-metadata-server-enabled" : "true"
        } : {
        "cloud.google.com/compute-class" : "Performance"
        "cloud.google.com/machine-family" : "c3"
        "cloud.google.com/gke-ephemeral-storage-local-ssd" : "true"
        "iam.gke.io/gke-metadata-server-enabled" : "true"
        } : var.enable_gpu ? {
        "iam.gke.io/gke-metadata-server-enabled" : "true"
        "cloud.google.com/gke-accelerator" : "nvidia-l4"
        } : var.enable_tpu ? {
        "iam.gke.io/gke-metadata-server-enabled" : "true"
        "cloud.google.com/gke-tpu-accelerator" : "tpu-v4-podslice"
        "cloud.google.com/gke-tpu-topology" : "2x2x1"
        "cloud.google.com/gke-placement-group" : "tpu-pool"
        } : {
        "iam.gke.io/gke-metadata-server-enabled" : "true"
      }
    })
  ]
}

data "kubernetes_service" "head-svc" {
  metadata {
    name      = "${helm_release.ray-cluster.name}-kuberay-head-svc"
    namespace = var.namespace
  }
  depends_on = [helm_release.ray-cluster]
}

# Allow ingress to the kuberay head from outside the cluster
resource "kubernetes_network_policy" "kuberay-head-namespace-network-policy" {
  count = var.disable_network_policy ? 0 : 1
  metadata {
    name      = "terraform-kuberay-head-namespace-network-policy"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        "ray.io/node-type" : "head"
      }
    }

    ingress {
      # Ray job submission and dashboard
      ports {
        port     = "8265"
        protocol = "TCP"
      }

      # Ray client
      ports {
        port     = "10001"
        protocol = "TCP"
      }

      from {
        namespace_selector {
          match_expressions {
            key      = "kubernetes.io/metadata.name"
            operator = "In"
            values   = var.network_policy_allow_namespaces
          }
        }
      }
    }

    policy_types = ["Ingress"]
  }
}

# Allow ingress to the kuberay head from outside the cluster
resource "kubernetes_network_policy" "kuberay-head-cidr-network-policy" {
  count = var.network_policy_allow_cidr != "" && !var.disable_network_policy ? 1 : 0
  metadata {
    name      = "terraform-kuberay-head-cidr-network-policy"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        "ray.io/node-type" : "head"
      }
    }

    ingress {
      # Ray job submission and dashboard
      ports {
        port     = "8265"
        protocol = "TCP"
      }

      # Ray client
      ports {
        port     = "10001"
        protocol = "TCP"
      }

      from {
        ip_block {
          cidr = var.network_policy_allow_cidr
        }
      }
    }

    policy_types = ["Ingress"]
  }
}

# Allow all same namespace and gmp traffic
resource "kubernetes_network_policy" "kuberay-cluster-allow-network-policy" {
  count = var.disable_network_policy ? 0 : 1
  metadata {
    name      = "terraform-kuberay-allow-cluster-network-policy"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        "ray.io/is-ray-node" : "yes"
      }
    }

    ingress {
      ports {
        protocol = "TCP"
      }

      from {
        namespace_selector {
          match_expressions {
            key      = "kubernetes.io/metadata.name"
            operator = "In"
            values   = [var.namespace, "gke-gmp-system", "gmp-system"]
          }
        }
      }
    }

    policy_types = ["Ingress"]
  }
}

# IAP Section: Creates the GKE components
module "iap_auth" {
  count  = var.add_auth ? 1 : 0
  source = "../../modules/iap"

  project_id               = var.project_id
  namespace                = var.namespace
  support_email            = var.support_email
  app_name                 = "ray-dashboard"
  create_brand             = var.create_brand
  k8s_ingress_name         = var.k8s_ingress_name
  k8s_managed_cert_name    = var.k8s_managed_cert_name
  k8s_iap_secret_name      = var.k8s_iap_secret_name
  k8s_backend_config_name  = var.k8s_backend_config_name
  k8s_backend_service_name = "${helm_release.ray-cluster.name}-kuberay-head-svc"
  k8s_backend_service_port = var.k8s_backend_service_port
  client_id                = var.client_id
  client_secret            = var.client_secret
  domain                   = var.domain
  members_allowlist        = var.members_allowlist
  depends_on = [
    helm_release.ray-cluster,
    data.kubernetes_service.head-svc,
  ]
}

