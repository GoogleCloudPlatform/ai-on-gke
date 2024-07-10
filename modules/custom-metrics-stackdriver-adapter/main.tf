locals {
  v1beta1-custom-metrics-k8s-io                             = "${path.module}/templates/apiservice_v1beta1.custom.metrics.k8s.io.yaml.tftpl"
  v1beta1-external-metrics-k8s-io                           = "${path.module}/templates/apiservice_v1beta1.external.metrics.k8s.io.yaml.tftpl"
  v1beta2-custom-metrics-k8s-io                             = "${path.module}/templates/apiservice_v1beta2.custom.metrics.k8s.io.yaml.tftpl"
  cluster-role-custom-metrics-resource-reader               = "${path.module}/templates/clusterrole_custom-metrics-resource-reader.yaml.tftpl"
  cluster-role-binding-custom-metrics-resource-reader       = "${path.module}/templates/clusterrolebinding_custom-metrics-resource-reader.yaml.tftpl"
  cluster-role-binding-custom-metrics-system-auth-delegator = "${path.module}/templates/clusterrolebinding_custom-metrics:system:auth-delegator.yaml.tftpl"
  cluster-role-binding-external-metrics-reader              = "${path.module}/templates/clusterrolebinding_external-metrics-reader.yaml.tftpl"
  deployment-custom-metrics-stackdriver-adapter             = "${path.module}/templates/deployment_custom-metrics-stackdriver-adapter.yaml.tftpl"
  service-custom-metrics-stackdriver-adapter                = "${path.module}/templates/service_custom-metrics-stackdriver-adapter.yaml.tftpl"
  service-account-custom-metrics-stackdriver-adapter        = "${path.module}/templates/serviceaccount_custom-metrics-stackdriver-adapter.yaml.tftpl"
  role-binding-custom-metrics-auth-reader                   = "${path.module}/templates/rolebinding_custom-metrics-auth-reader.yaml.tftpl"
}

resource "kubernetes_namespace_v1" "custom-metrics" {
  metadata {
    name = "custom-metrics"
  }
}

resource "kubernetes_service_account_v1" "service-account-custom-metrics-stackdriver-adapter" {
  metadata {
    name      = "custom-metrics-stackdriver-adapter"
    namespace = kubernetes_namespace_v1.custom-metrics.metadata[0].name
    annotations = var.workload_identity.enabled ? {
      "iam.gke.io/gcp-service-account" = google_service_account.cmsa-sa[0].email
    } : {}
  }
}

resource "kubernetes_manifest" "custom-metrics-system-auth-delegator" {
  count = 1
  manifest = yamldecode(templatefile(local.cluster-role-binding-custom-metrics-system-auth-delegator, {
    cmsa-serviceaccount-name = kubernetes_service_account_v1.service-account-custom-metrics-stackdriver-adapter.metadata[0].name
  }))
}

resource "kubernetes_manifest" "role-binding-custom-metrics-auth-reader" {
  count = 1
  manifest = yamldecode(templatefile(local.role-binding-custom-metrics-auth-reader, {
    cmsa-serviceaccount-name = kubernetes_service_account_v1.service-account-custom-metrics-stackdriver-adapter.metadata[0].name
  }))
}

resource "kubernetes_manifest" "cluster-role-custom-metrics-resource-reader" {
  count    = 1
  manifest = yamldecode(file(local.cluster-role-custom-metrics-resource-reader))
}

resource "kubernetes_manifest" "cluster-role-binding-custom-metrics-resource-reader" {
  count = 1
  manifest = yamldecode(templatefile(local.cluster-role-binding-custom-metrics-resource-reader, {
    cmsa-serviceaccount-name = kubernetes_service_account_v1.service-account-custom-metrics-stackdriver-adapter.metadata[0].name
  }))
}

resource "kubernetes_manifest" "deployment-custom-metrics-stackdriver-adapter" {
  count = 1
  manifest = yamldecode(templatefile(local.deployment-custom-metrics-stackdriver-adapter, {
    cmsa-serviceaccount-name = kubernetes_service_account_v1.service-account-custom-metrics-stackdriver-adapter.metadata[0].name
  }))
}

resource "kubernetes_manifest" "service-custom-metrics-stackdriver-adapter" {
  count    = 1
  manifest = yamldecode(file(local.service-custom-metrics-stackdriver-adapter))
}

resource "kubernetes_manifest" "v1beta1-custom-metrics-k8s-io" {
  count    = 1
  manifest = yamldecode(file(local.v1beta1-custom-metrics-k8s-io))
}

resource "kubernetes_manifest" "v1beta2-custom-metrics-k8s-io" {
  count    = 1
  manifest = yamldecode(file(local.v1beta2-custom-metrics-k8s-io))
}

resource "kubernetes_manifest" "v1beta1-external-metrics-k8s-io" {
  count    = 1
  manifest = yamldecode(file(local.v1beta1-external-metrics-k8s-io))
}

resource "kubernetes_manifest" "external-metrics-reader" {
  count    = 1
  manifest = yamldecode(file(local.cluster-role-binding-external-metrics-reader))
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

# Equivalent to:
#   gcloud projects add-iam-policy-binding PROJECT_ID \
#       --member=serviceAccount:cmsa-sa@PROJECT_ID.iam.gserviceaccount.com \
#       --role=roles/monitoring.viewer
resource "google_project_iam_binding" "cmsa-project-binding-sa-monitoring-viewer" {
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
#       --member "serviceAccount:PROJECT_ID.svc.id.goog[custom-metrics/custom-metrics-stackdriver-adapter]" \
#       cmsa-sa@PROJECT_ID.iam.gserviceaccount.com
resource "google_service_account_iam_member" "cmsa-bind-to-gsa" {
  count              = var.workload_identity.enabled ? 1 : 0
  service_account_id = google_service_account.cmsa-sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.workload_identity.project_id}.svc.id.goog[custom-metrics/custom-metrics-stackdriver-adapter]"
}
