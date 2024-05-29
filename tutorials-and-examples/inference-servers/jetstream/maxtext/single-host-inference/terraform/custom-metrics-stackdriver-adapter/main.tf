resource "kubernetes_namespace_v1" "slabe-jetstream" {
  metadata {
    name = "slabe-jetstream"
  }
}

resource "kubernetes_service_account_v1" "custom-metrics-stackdriver-adapter-no-wi" {
  count = var.workload_identity.enabled ? 0 : 1
  metadata {
    name      = "custom-metrics-stackdriver-adapter"
    namespace = kubernetes_namespace_v1.slabe-jetstream.metadata[0].name
  }
}

resource "kubernetes_service_account_v1" "custom-metrics-stackdriver-adapter-wi" {
  count = var.workload_identity.enabled ? 1 : 0
  metadata {
    name      = "custom-metrics-stackdriver-adapter"
    namespace = kubernetes_namespace_v1.slabe-jetstream.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.cmsa-sa[0].email
    }
  }
}

resource "kubernetes_cluster_role_binding_v1" "custom-metrics-system-auth-delegator" {
  metadata {
    name = "slabe-jetstream:system:auth-delegator"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }
  subject {
    kind = "ServiceAccount"
    name = (var.workload_identity.enabled
      ? kubernetes_service_account_v1.custom-metrics-stackdriver-adapter-wi[0].metadata[0].name
      : kubernetes_service_account_v1.custom-metrics-stackdriver-adapter-no-wi[0].metadata[0].name
    )
    namespace = kubernetes_namespace_v1.slabe-jetstream.metadata[0].name
  }
}

resource "kubernetes_role_binding_v1" "custom-metrics-auth-reader" {
  metadata {
    name      = "custom-metrics-auth-reader"
    namespace = "kube-system"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "extension-apiserver-authentication-reader"
  }
  subject {
    kind = "ServiceAccount"
    name = (var.workload_identity.enabled
      ? kubernetes_service_account_v1.custom-metrics-stackdriver-adapter-wi[0].metadata[0].name
      : kubernetes_service_account_v1.custom-metrics-stackdriver-adapter-no-wi[0].metadata[0].name
    )
    namespace = kubernetes_namespace_v1.slabe-jetstream.metadata[0].name
  }
}

resource "kubernetes_cluster_role_v1" "custom-metrics-resource-reader" {
  metadata {
    name = "custom-metrics-resource-reader"
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "nodes/stats"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "custom-metrics-resource-reader" {
  metadata {
    name = "custom-metrics-resource-reader"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.custom-metrics-resource-reader.metadata[0].name
  }
  subject {
    kind = "ServiceAccount"
    name = (var.workload_identity.enabled
      ? kubernetes_service_account_v1.custom-metrics-stackdriver-adapter-wi[0].metadata[0].name
      : kubernetes_service_account_v1.custom-metrics-stackdriver-adapter-no-wi[0].metadata[0].name
    )
    namespace = kubernetes_namespace_v1.slabe-jetstream.metadata[0].name
  }
}

resource "kubernetes_deployment_v1" "custom-metrics-stackdriver-adapter" {
  metadata {
    name      = "custom-metrics-stackdriver-adapter"
    namespace = kubernetes_namespace_v1.slabe-jetstream.metadata[0].name
    labels = {
      run     = "custom-metrics-stackdriver-adapter"
      k8s-app = "custom-metrics-stackdriver-adapter"
    }
  }
  spec {
    replicas = 1

    selector {
      match_labels = {
        run     = "custom-metrics-stackdriver-adapter"
        k8s-app = "custom-metrics-stackdriver-adapter"
      }
    }

    template {
      metadata {
        labels = {
          run                             = "custom-metrics-stackdriver-adapter"
          k8s-app                         = "custom-metrics-stackdriver-adapter"
          "kubernetes.io/cluster-service" = "true"
        }
      }

      spec {
        service_account_name = (var.workload_identity.enabled
          ? kubernetes_service_account_v1.custom-metrics-stackdriver-adapter-wi[0].metadata[0].name
          : kubernetes_service_account_v1.custom-metrics-stackdriver-adapter-no-wi[0].metadata[0].name
        )

        container {
          image             = "gcr.io/gke-release/custom-metrics-stackdriver-adapter:v0.14.2-gke.0"
          image_pull_policy = "Always"
          name              = "pod-custom-metrics-stackdriver-adapter"
          command           = ["/adapter", "--use-new-resource-model=true", "--fallback-for-container-metrics=true"]
          resources {
            limits = {
              cpu    = "250m"
              memory = "200Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "200Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "custom-metrics-stackdriver-adapter" {
  metadata {
    name      = "custom-metrics-stackdriver-adapter"
    namespace = kubernetes_namespace_v1.slabe-jetstream.metadata[0].name
    labels = {
      run                             = "custom-metrics-stackdriver-adapter"
      k8s-app                         = "custom-metrics-stackdriver-adapter"
      "kubernetes.io/cluster-service" = "true"
      "kubernetes.io/name"            = "Adapter"
    }
  }
  spec {
    selector = {
      run     = "custom-metrics-stackdriver-adapter"
      k8s-app = "custom-metrics-stackdriver-adapter"
    }
    port {
      port        = 443
      protocol    = "TCP"
      target_port = 443
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_api_service_v1" "v1beta1-custom-metrics-k8s-io" {
  metadata {
    name = "v1beta1.custom.metrics.k8s.io"
  }
  spec {
    insecure_skip_tls_verify = true
    group                    = "custom.metrics.k8s.io"
    group_priority_minimum   = 100
    version_priority         = 100
    service {
      name      = kubernetes_service_v1.custom-metrics-stackdriver-adapter.metadata[0].name
      namespace = kubernetes_namespace_v1.slabe-jetstream.metadata[0].name
    }
    version = "v1beta1"
  }
}

resource "kubernetes_api_service_v1" "v1beta2-custom-metrics-k8s-io" {
  metadata {
    name = "v1beta2.custom.metrics.k8s.io"
  }
  spec {
    insecure_skip_tls_verify = true
    group                    = "custom.metrics.k8s.io"
    group_priority_minimum   = 100
    version_priority         = 200
    service {
      name      = kubernetes_service_v1.custom-metrics-stackdriver-adapter.metadata[0].name
      namespace = kubernetes_namespace_v1.slabe-jetstream.metadata[0].name
    }
    version = "v1beta2"
  }
}

resource "kubernetes_api_service_v1" "v1beta1-external-metrics-k8s-io" {
  metadata {
    name = "v1beta1.external.metrics.k8s.io"
  }
  spec {
    insecure_skip_tls_verify = true
    group                    = "external.metrics.k8s.io"
    group_priority_minimum   = 100
    version_priority         = 100
    service {
      name      = kubernetes_service_v1.custom-metrics-stackdriver-adapter.metadata[0].name
      namespace = kubernetes_namespace_v1.slabe-jetstream.metadata[0].name
    }
    version = "v1beta1"
  }
}

resource "kubernetes_cluster_role_binding_v1" "external-metrics-reader" {
  metadata {
    name = "external-metrics-reader"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "external-metrics-reader"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "horizontal-pod-autoscaler"
    namespace = "kube-system"
  }
}


# If workload identity is enabled, extra steps are required. We need to:
# - create a service account
# - grant it the monitoring.viewer IAM role
# - bind it to the workload identity user for the cmsa
# - annotate the cmsa service account (done above)

resource "google_service_account" "cmsa-sa" {
  count      = var.workload_identity.enabled ? 1 : 0
  account_id = "cmsa-sa"
  project    = var.workload_identity.project_id
}

# Need to do this in terraform
# gcloud projects add-iam-policy-binding tpu-vm-gke-testing --member=serviceAccount:cmsa-sa@tpu-vm-gke-testing.iam.gserviceaccount.com --role=roles/monitoring.viewer --role=roles/monitoring.metricWriter --role=roles/iam.serviceAccountTokenCreator --role=roles/storage.admin --role=roles/storage.objectAdmin --role=roles/storage.objectCreator
# gcloud iam service-accounts add-iam-policy-binding --role roles/iam.workloadIdentityUser --member "serviceAccount:tpu-vm-gke-testing.svc.id.goog[slabe-jetstream/custom-metrics-stackdriver-adapter]" cmsa-sa@tpu-vm-gke-testing.iam.gserviceaccount.com

# Equivalent to:
#   gcloud projects add-iam-policy-binding PROJECT_ID \
#       --member=serviceAccount:cmsa-sa@PROJECT_ID.iam.gserviceaccount.com \
#       --role=roles/monitoring.viewer
resource "google_project_iam_binding" "cmsa-project-binding-monitoring-viewer" {
  count   = var.workload_identity.enabled ? 1 : 0
  project = var.workload_identity.project_id
  role    = "roles/monitoring.viewer"
  members = [
    "serviceAccount:${google_service_account.cmsa-sa[0].account_id}@${var.workload_identity.project_id}.iam.gserviceaccount.com"
  ]
}

# Equivalent to:
#   gcloud projects add-iam-policy-binding PROJECT_ID \
#       --member=serviceAccount:cmsa-sa@PROJECT_ID.iam.gserviceaccount.com \
#       --role=roles/iam.serviceAccountTokenCreator
resource "google_project_iam_binding" "cmsa-project-binding-sa-token-creator" {
  count   = var.workload_identity.enabled ? 1 : 0
  project = var.workload_identity.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  members = [
    "serviceAccount:${google_service_account.cmsa-sa[0].account_id}@${var.workload_identity.project_id}.iam.gserviceaccount.com"
  ]
}

# Equivalent to:
#   gcloud iam service-accounts add-iam-policy-binding \
#       --role roles/iam.workloadIdentityUser \
#       --member "serviceAccount:PROJECT_ID.svc.id.goog[slabe-jetstream/custom-metrics-stackdriver-adapter]" \
#       cmsa-sa@PROJECT_ID.iam.gserviceaccount.com
resource "google_service_account_iam_member" "cmsa-bind-to-gsa" {
  count              = var.workload_identity.enabled ? 1 : 0
  service_account_id = google_service_account.cmsa-sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.workload_identity.project_id}.svc.id.goog[custom-metrics/custom-metrics-stackdriver-adapter]"
}
