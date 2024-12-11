resource "null_resource" "matchmaker_frontend_cloud_build" {
  triggers = {
    files_hash = local.matchmaker_frontend_files_hash
  }

  provisioner "local-exec" {
    command = <<EOT
      gcloud builds submit --project ${local.project_id} \
                           --tag ${var.region}-docker.pkg.dev/${local.project_id}/${var.repository_id}/${var.matchmaker_frontend_container_name}:latest \
                           ../matchmaker/frontend/
    EOT
  }
  depends_on = [
    google_project_iam_member.compute_roles,
    google_project_iam_member.cloudbuild_roles,
    google_artifact_registry_repository.my_repo
  ]
}

resource "kubectl_manifest" "matchmaker-frontend-deployment" {
  yaml_body = templatefile("${path.module}/k8s_templates/matchmaker-frontend-deployment.yaml.tpl", {
    project_id     = local.project_id,
    container_name = var.matchmaker_frontend_container_name,
    repo_name      = var.repository_id,
    region         = var.region,
  })

  depends_on = [
    google_container_cluster.autopilot_cluster,
    null_resource.matchmaker_frontend_cloud_build,
    helm_release.open_match
  ]
}

resource "kubectl_manifest" "matchmaker-frontend-service" {
  yaml_body = templatefile("${path.module}/k8s_templates/matchmaker-frontend-service.yaml.tpl", {})

  depends_on = [
    google_container_cluster.autopilot_cluster,
    null_resource.matchmaker_frontend_cloud_build,
    helm_release.open_match,
    kubectl_manifest.matchmaker-frontend-deployment
  ]
}