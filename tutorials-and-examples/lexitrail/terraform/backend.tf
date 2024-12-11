resource "null_resource" "backend_cloud_build" {
  triggers = {
    files_hash = local.backend_files_hash
  }

  provisioner "local-exec" {
    command = <<EOT
      gcloud builds submit --project ${local.project_id} \
                           --tag ${var.region}-docker.pkg.dev/${local.project_id}/${var.repository_id}/${var.backend_container_name}:latest \
                           ../backend/
    EOT
  }
  depends_on = [
    google_project_iam_member.compute_roles,
    google_project_iam_member.cloudbuild_roles,
    google_artifact_registry_repository.my_repo
  ]
}

resource "kubectl_manifest" "backend_namespace" {
  yaml_body = templatefile("${path.module}/k8s_templates/backend-namespace.yaml.tpl", {
    backend_namespace = var.backend_namespace,
    gsa_email         = google_service_account.lexitrail_sa.email
  })
  depends_on = [
    google_container_cluster.autopilot_cluster
  ]
}

resource "kubectl_manifest" "backend_deployment" {
  yaml_body = templatefile("${path.module}/k8s_templates/backend-deployment.yaml.tpl", {
    project_id        = local.project_id,
    container_name    = var.backend_container_name,
    repo_name         = var.repository_id,
    region            = var.region,
    backend_namespace = var.backend_namespace,
    backend_files_hash = local.backend_files_hash
  })
  depends_on = [
    google_container_cluster.autopilot_cluster,
    kubectl_manifest.backend_namespace,
    null_resource.backend_cloud_build,
    google_service_account_iam_member.lexitrail_workload_identity_binding_backend
  ]
}

resource "kubectl_manifest" "backend_service" {
  yaml_body = templatefile("${path.module}/k8s_templates/backend-service.yaml.tpl", {
    backend_namespace = var.backend_namespace
  })
  depends_on = [
    google_container_cluster.autopilot_cluster,
    kubectl_manifest.backend_namespace,
    kubectl_manifest.backend_deployment
  ]
}

resource "kubectl_manifest" "backend_configmap" {
  yaml_body = templatefile("${path.module}/k8s_templates/backend-configmap.yaml.tpl", {
    backend_namespace = var.backend_namespace,
    mysql_files_bucket = google_storage_bucket.mysql_files_bucket.name,
    sql_namespace = var.sql_namespace,
    database_name = var.db_name,
    google_client_id = local.google_client_id,
    project_id = local.project_id,
    location = var.region
  })
  depends_on = [
    google_container_cluster.autopilot_cluster,
    kubectl_manifest.backend_namespace,
    google_storage_bucket.mysql_files_bucket
  ]
}

resource "kubectl_manifest" "backend_secret" {
  yaml_body = templatefile("${path.module}/k8s_templates/backend-secret.yaml.tpl", {
    backend_namespace = var.backend_namespace,
    db_root_password  = base64encode(local.db_root_password)
  })
  depends_on = [google_container_cluster.autopilot_cluster, kubectl_manifest.backend_namespace]
}

resource "kubectl_manifest" "backend_default_sa_annotation" {
  yaml_body = templatefile("${path.module}/k8s_templates/backend-default-service-account.yaml.tpl", {
    backend_namespace = var.backend_namespace,
    gsa_email         = google_service_account.lexitrail_sa.email
  })
  depends_on = [
    google_container_cluster.autopilot_cluster,
    kubectl_manifest.backend_namespace
  ]
}