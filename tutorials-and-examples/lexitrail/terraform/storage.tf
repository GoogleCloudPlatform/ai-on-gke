resource "google_artifact_registry_repository" "my_repo" {
  provider      = google
  location      = var.region
  repository_id = var.repository_id
  description   = "Lexitrail registry"
  format        = "DOCKER"
  depends_on = [
    google_project_iam_member.compute_roles,
    google_project_iam_member.cloudbuild_roles
  ]
}

resource "google_storage_bucket" "mysql_files_bucket" {
  name     = "${local.project_id}-lexitrail-mysql-files"
  location = var.region

  uniform_bucket_level_access = true
  depends_on = [
    google_project_iam_member.compute_roles,
    google_project_iam_member.cloudbuild_roles
  ]
}

resource "google_storage_bucket_object" "schema_tables_sql" {
  name   = "schema-tables.sql"
  bucket = google_storage_bucket.mysql_files_bucket.name
  source = "${path.module}/schema-tables.sql"

  depends_on = [null_resource.schema_tables_sql_trigger]
}

resource "google_storage_bucket_object" "schema_data_sql" {
  name   = "schema-data.sql"
  bucket = google_storage_bucket.mysql_files_bucket.name
  source = "${path.module}/schema-data.sql"

  depends_on = [null_resource.schema_data_sql_trigger]
}

resource "google_storage_bucket_object" "wordsets_csv" {
  name   = "csv/wordsets.csv"
  bucket = google_storage_bucket.mysql_files_bucket.name
  source = "${path.module}/csv/wordsets.csv"

  depends_on = [null_resource.csv_files_trigger]
}

resource "google_storage_bucket_object" "words_csv" {
  name   = "csv/words.csv"
  bucket = google_storage_bucket.mysql_files_bucket.name
  source = "${path.module}/csv/words.csv"

  depends_on = [null_resource.csv_files_trigger]
}