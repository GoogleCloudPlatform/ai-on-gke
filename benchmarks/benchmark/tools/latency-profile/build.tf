resource "null_resource" "build_and_push_image" {

  depends_on = [resource.google_project_service.cloudbuild]
  provisioner "local-exec" {
    working_dir = path.module
    command     = "gcloud builds submit --tag ${var.artifact_registry}/latency-profile:latest container"
  }
}