resource "google_project_iam_member" "cloudbuild_roles" {
  for_each = toset([
    "roles/storage.admin",
    "roles/logging.logWriter",
    "roles/artifactregistry.admin",
    "roles/reader",
    "roles/storage.objectCreator",
    "roles/serviceusage.serviceUsageConsumer",
    "roles/cloudbuild.builds.editor"
  ])

  project = local.project_id
  member  = "serviceAccount:${data.google_project.default.number}@cloudbuild.gserviceaccount.com"
  role    = each.value
}

resource "google_project_iam_member" "compute_roles" {
  for_each = toset([
    "roles/storage.admin",
    "roles/logging.logWriter",
    "roles/artifactregistry.admin",
    "roles/reader",
    "roles/storage.objectCreator",
    "roles/serviceusage.serviceUsageConsumer",
    "roles/cloudbuild.builds.editor"
  ])

  project = local.project_id
  member  = "serviceAccount:${data.google_project.default.number}-compute@developer.gserviceaccount.com"
  role    = each.value
}

resource "google_project_iam_member" "bucket_access" {
  project = local.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.lexitrail_sa.email}"
}

resource "google_project_iam_member" "vertex_ai_access" {
  project = local.project_id
  role    = "roles/aiplatform.admin"
  member  = "serviceAccount:${google_service_account.lexitrail_sa.email}"
}

resource "google_service_account_iam_member" "lexitrail_workload_identity_binding_mysql" {
  service_account_id = google_service_account.lexitrail_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.project_id}.svc.id.goog[mysql/default]"
}

resource "google_service_account_iam_member" "lexitrail_workload_identity_binding_backend" {
  service_account_id = google_service_account.lexitrail_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.project_id}.svc.id.goog[${var.backend_namespace}/default]"
}