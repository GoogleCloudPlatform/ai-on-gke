resource "kubectl_manifest" "mysql_namespace" {
  yaml_body = templatefile("${path.module}/k8s_templates/mysql-namespace.yaml.tpl", {
    sql_namespace = var.sql_namespace,
    gsa_email     = google_service_account.lexitrail_sa.email
  })
  depends_on = [
    google_container_cluster.autopilot_cluster
  ]
}

resource "kubectl_manifest" "default_sa_annotation" {
  yaml_body = templatefile("${path.module}/k8s_templates/mysql-default-service-account.yaml.tpl", {
    sql_namespace = var.sql_namespace,
    gsa_email     = google_service_account.lexitrail_sa.email
  })
  depends_on = [
    google_container_cluster.autopilot_cluster
  ]
}

resource "kubectl_manifest" "mysql_pvc" {
  yaml_body = templatefile("${path.module}/k8s_templates/mysql-pvc.yaml.tpl", {
    sql_namespace = var.sql_namespace
  })
  depends_on = [google_container_cluster.autopilot_cluster, kubectl_manifest.mysql_namespace]
}

resource "kubectl_manifest" "mysql_service" {
  yaml_body = templatefile("${path.module}/k8s_templates/mysql-service.yaml.tpl", {
    sql_namespace = var.sql_namespace
  })
  depends_on = [google_container_cluster.autopilot_cluster, kubectl_manifest.mysql_namespace]
}

resource "kubectl_manifest" "mysql_deployment" {
  yaml_body = templatefile("${path.module}/k8s_templates/mysql-deployment.yaml.tpl", {
    sql_namespace    = var.sql_namespace,
    db_root_password = local.db_root_password,
    terraform_time   = timestamp()
  })
  depends_on = [google_container_cluster.autopilot_cluster, kubectl_manifest.mysql_pvc, kubectl_manifest.mysql_service]
}

resource "kubectl_manifest" "mysql_schema_and_data_job" {
  yaml_body = templatefile("${path.module}/k8s_templates/mysql-schema-and-data-job.yaml.tpl", {
    sql_namespace      = var.sql_namespace,
    db_root_password   = local.db_root_password,
    mysql_files_bucket = google_storage_bucket.mysql_files_bucket.name,
    db_name            = var.db_name,
    files_hash = sha1(join("", [
      filesha1("${path.module}/schema-tables.sql"),
      filesha1("${path.module}/schema-data.sql"),
      sha1(join("", [for f in fileset("${path.module}/csv", "**/*") : filesha1("${path.module}/csv/${f}")]))
    ]))
  })

  depends_on = [
    google_container_cluster.autopilot_cluster,
    kubectl_manifest.mysql_deployment,
    google_storage_bucket_object.schema_tables_sql,
    google_storage_bucket_object.schema_data_sql,
    google_storage_bucket_object.wordsets_csv,
    google_storage_bucket_object.words_csv,
    google_service_account_iam_member.lexitrail_workload_identity_binding_mysql,
    google_project_iam_member.bucket_access,
    null_resource.schema_tables_sql_trigger,
    null_resource.schema_data_sql_trigger,
    null_resource.csv_files_trigger
  ]
}