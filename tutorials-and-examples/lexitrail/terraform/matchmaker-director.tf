resource "null_resource" "matchmaker_director_cloud_build" {
  triggers = {
    files_hash = local.matchmaker_director_files_hash
  }

  provisioner "local-exec" {
    command = <<EOT
      gcloud builds submit --project ${local.project_id} \
                           --tag ${var.region}-docker.pkg.dev/${local.project_id}/${var.repository_id}/${var.matchmaker_director_container_name}:latest \
                           ../matchmaker/director/
    EOT
  }
  depends_on = [
    google_project_iam_member.compute_roles,
    google_project_iam_member.cloudbuild_roles,
    google_artifact_registry_repository.my_repo
  ]
}

resource "kubectl_manifest" "matchmaker-director-deployment" {
  yaml_body = templatefile("${path.module}/k8s_templates/matchmaker-director-deployment.yaml.tpl", {
    project_id     = local.project_id,
    container_name = var.matchmaker_director_container_name,
    repo_name      = var.repository_id,
    region         = var.region,
  })

  depends_on = [
    google_container_cluster.autopilot_cluster,
    null_resource.matchmaker_director_cloud_build,
    helm_release.open_match
  ]
}

resource "kubectl_manifest" "matchmaker-director-service-account" {
  yaml_body = templatefile("${path.module}/k8s_templates/matchmaker-director-service-account.yaml.tpl", {})

  depends_on = [
    google_container_cluster.autopilot_cluster,
    null_resource.matchmaker_director_cloud_build,
    helm_release.open_match
  ]
}

resource "kubectl_manifest" "matchmaker-director-cluster-role" {
  yaml_body = templatefile("${path.module}/k8s_templates/matchmaker-director-cluster-role.yaml.tpl", {})

  depends_on = [
    kubectl_manifest.matchmaker-director-service-account
  ]
}

resource "kubectl_manifest" "matchmaker-director-cluster-role-binding" {
  yaml_body = templatefile("${path.module}/k8s_templates/matchmaker-director-cluster-role-binding.yaml.tpl", {})

  depends_on = [
    kubectl_manifest.matchmaker-director-cluster-role
  ]
}