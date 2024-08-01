data "google_project" "environment" {
  project_id = var.environment_project_id
}

resource "google_project_service" "compute_googleapis_com" {
  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = data.google_project.environment.project_id
  service                    = "compute.googleapis.com"
}
