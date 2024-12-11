resource "null_resource" "schema_tables_sql_trigger" {
  triggers = {
    file_hash = filesha1("${path.module}/schema-tables.sql")
  }

  provisioner "local-exec" {
    command = "echo Triggered re-upload of schema-tables.sql"
  }
}

resource "null_resource" "schema_data_sql_trigger" {
  triggers = {
    file_hash = filesha1("${path.module}/schema-data.sql")
  }

  provisioner "local-exec" {
    command = "echo Triggered re-upload of schema-data.sql"
  }
}

resource "null_resource" "csv_files_trigger" {
  triggers = {
    files_hash = sha1(join("", [for f in fileset("${path.module}/csv", "**/*") : filesha1("${path.module}/csv/${f}")]))
  }

  provisioner "local-exec" {
    command = "echo Triggered re-upload of CSV files"
  }
}