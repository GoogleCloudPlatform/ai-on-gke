resource "null_resource" "cloud_build" {
  triggers = {
    files_hash = local.ui_files_hash
  }

  provisioner "local-exec" {
    command = <<EOT
      gcloud builds submit --project ${local.project_id} \
                           --tag ${var.region}-docker.pkg.dev/${local.project_id}/${var.repository_id}/${var.container_name}:latest \
                           ../ui/
    EOT
  }
  depends_on = [
    google_project_iam_member.compute_roles,
    google_project_iam_member.cloudbuild_roles
  ]
}

resource "kubectl_manifest" "lexitrail_ui_deployment" {
  yaml_body = templatefile("${path.module}/k8s_templates/deploy-deployment.yaml.tpl", {
    project_id     = local.project_id,
    container_name = var.container_name,
    repo_name      = var.repository_id,
    region         = var.region,
    ui_files_hash  = local.ui_files_hash
  })

  depends_on = [
    google_container_cluster.autopilot_cluster,
    null_resource.cloud_build
  ]
}

resource "kubectl_manifest" "lexitrail_ui_service" {
  yaml_body = templatefile("${path.module}/k8s_templates/deploy-service.yaml.tpl", {})

  depends_on = [
    google_container_cluster.autopilot_cluster
  ]
}