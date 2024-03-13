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
  security_context                  = chomp(yamlencode({ for k, v in var.security_context : k => v if v != null }))
  cloudsql_instance_connection_name = format("%s:%s:%s", var.project_id, var.db_region, var.cloudsql_instance_name)
}

resource "helm_release" "ray-cluster" {
  name             = var.name
  repository       = "https://ray-project.github.io/kuberay-helm/"
  chart            = "ray-cluster"
  namespace        = var.namespace
  create_namespace = true
  version          = "1.0.0"
  values = [
    var.autopilot_cluster ? templatefile("${path.module}/kuberay-autopilot-values.yaml", {
      gcs_bucket                        = var.gcs_bucket
      k8s_service_account               = var.google_service_account
      grafana_host                      = var.grafana_host
      security_context                  = local.security_context
      secret_name                       = var.db_secret_name
      cloudsql_instance_connection_name = local.cloudsql_instance_connection_name
      }) : var.enable_tpu ? templatefile("${path.module}/kuberay-tpu-values.yaml", {
      gcs_bucket                        = var.gcs_bucket
      k8s_service_account               = var.google_service_account
      grafana_host                      = var.grafana_host
      security_context                  = local.security_context
      secret_name                       = var.db_secret_name
      cloudsql_instance_connection_name = local.cloudsql_instance_connection_name
      }) : var.enable_gpu ? templatefile("${path.module}/kuberay-gpu-values.yaml", {
      gcs_bucket                        = var.gcs_bucket
      k8s_service_account               = var.google_service_account
      grafana_host                      = var.grafana_host
      security_context                  = local.security_context
      secret_name                       = var.db_secret_name
      cloudsql_instance_connection_name = local.cloudsql_instance_connection_name
      }) : templatefile("${path.module}/kuberay-values.yaml", {
      gcs_bucket                        = var.gcs_bucket
      k8s_service_account               = var.google_service_account
      grafana_host                      = var.grafana_host
      security_context                  = local.security_context
      secret_name                       = var.db_secret_name
      cloudsql_instance_connection_name = local.cloudsql_instance_connection_name
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
resource "kubernetes_network_policy" "kuberay-head-network-policy" {
  count = var.disable_network_policy ? 0 : 1
  metadata {
    name      = "terraform-kuberay-head-network-policy"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        "ray.io/is-ray-node" : "yes"
      }
    }

    ingress {
      # Ray Client server
      ports {
        port     = "10001"
        protocol = "TCP"
      }
      # Ray Dashboard
      ports {
        port     = "8265"
        protocol = "TCP"
      }

      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = var.namespace
          }
        }
        dynamic "namespace_selector" {
          for_each = var.network_policy_allow_namespaces_by_label
          content {
            match_labels = {
              each.key = each.value
            }
          }
        }

        dynamic "pod_selector" {
          for_each = var.network_policy_allow_pods_by_label
          content {
            match_labels = {
              each.key = each.value
            }
          }
        }

        dynamic "ip_block" {
          for_each = var.network_policy_allow_ips
          content {
            cidr = each.key
          }
        }
      }
    }

    policy_types = ["Ingress"]
  }
}

# Allow all intranamespace traffic to allow intracluster traffic
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
          match_labels = {
            "kubernetes.io/metadata.name" = var.namespace
          }
        }
      }
    }

    policy_types = ["Ingress"]
  }
}
