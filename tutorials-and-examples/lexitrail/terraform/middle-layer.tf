resource "null_resource" "middle_layer_cloud_build" {
  triggers = {
    files_hash = local.middle_layer_files_hash
  }

  provisioner "local-exec" {
    command = <<EOT
      gcloud builds submit --project ${local.project_id} \
                           --tag ${var.region}-docker.pkg.dev/${local.project_id}/${var.repository_id}/${var.middel_layer_container_name}:latest \
                           ../middle_layer/
    EOT
  }
  depends_on = [
    google_project_iam_member.compute_roles,
    google_project_iam_member.cloudbuild_roles,
    google_artifact_registry_repository.my_repo
  ]
}

resource "kubectl_manifest" "middle-layer-fleet" {
  yaml_body = templatefile("${path.module}/k8s_templates/middle-layer-fleet.yaml.tpl", {
    project_id     = local.project_id,
    container_name = var.middel_layer_container_name,
    repo_name      = var.repository_id,
    region         = var.region,
  })

  depends_on = [
    google_container_cluster.autopilot_cluster,
    null_resource.middle_layer_cloud_build,
    helm_release.agones
  ]
}

resource "kubectl_manifest" "middle-layer-fleet-autoscaler" {
  yaml_body = templatefile("${path.module}/k8s_templates/middle-layer-fleet-autoscaler.yaml.tpl", {})

  depends_on = [
    kubectl_manifest.middle-layer-fleet
  ]
}
