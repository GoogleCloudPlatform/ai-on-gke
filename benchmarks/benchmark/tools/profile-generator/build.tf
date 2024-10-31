resource "null_resource" "build_and_push_image" {
  count      = var.build_latency_profile_generator_image ? 1 : 0
  depends_on = [resource.google_project_service.cloudbuild]
  provisioner "local-exec" {
    working_dir = path.module
    command     = "gcloud builds submit --tag ${var.artifact_registry}/latency-profile:latest container"
  }
}