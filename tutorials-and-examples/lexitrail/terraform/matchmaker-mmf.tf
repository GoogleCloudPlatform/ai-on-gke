resource "null_resource" "matchmaker_mmf_cloud_build" {
  triggers = {
    files_hash = local.matchmaker_mmf_files_hash
  }

  provisioner "local-exec" {
    command = <<EOT
      gcloud builds submit --project ${local.project_id} \
                           --tag ${var.region}-docker.pkg.dev/${local.project_id}/${var.repository_id}/${var.matchmaker_mmf_container_name}:latest \
                           ../matchmaker/mmf/
    EOT
  }
  depends_on = [
    google_project_iam_member.compute_roles,
    google_project_iam_member.cloudbuild_roles,
    google_artifact_registry_repository.my_repo
  ]
}

resource "kubectl_manifest" "matchmaker-mmf-deployment" {
  yaml_body = templatefile("${path.module}/k8s_templates/matchmaker-mmf-deployment.yaml.tpl", {
    project_id     = local.project_id,
    container_name = var.matchmaker_mmf_container_name,
    repo_name      = var.repository_id,
    region         = var.region,
  })

  depends_on = [
    google_container_cluster.autopilot_cluster,
    null_resource.matchmaker_mmf_cloud_build,
    helm_release.open_match
  ]
}

resource "kubectl_manifest" "matchmaker-mmf-service" {
  yaml_body = templatefile("${path.module}/k8s_templates/matchmaker-mmf-service.yaml.tpl", {})

  depends_on = [
    google_container_cluster.autopilot_cluster,
    null_resource.matchmaker_mmf_cloud_build,
    helm_release.open_match,
    kubectl_manifest.matchmaker-mmf-deployment
  ]
}