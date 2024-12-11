output "gke_cluster_name" {
  value = google_container_cluster.autopilot_cluster.name
}

output "files_hash" {
  value = md5(join("", fileset("../ui/", "**")))
}

output "mysql_files_bucket_name" {
  value = google_storage_bucket.mysql_files_bucket.name
}