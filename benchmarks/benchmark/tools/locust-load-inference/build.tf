resource "null_resource" "build_and_push_image" {

  depends_on = [resource.google_project_service.cloudbuild]
  provisioner "local-exec" {
    working_dir = path.module
    command     = "gcloud builds submit --tag ${var.artifact_registry}/locust-tasks:latest locust-docker"
  }
}

resource "null_resource" "build_and_push_runner_image" {

  provisioner "local-exec" {
    working_dir = path.module
    command     = "gcloud builds submit --tag ${var.artifact_registry}/locust-runner:latest locust-runner"
  }
}

resource "null_resource" "build_and_push_exporter_image" {

  provisioner "local-exec" {
    working_dir = path.module
    command     = "gcloud builds submit --tag ${var.artifact_registry}/locust-custom-exporter:latest locust-custom-exporter"
  }
}