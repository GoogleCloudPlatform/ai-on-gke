resource "google_filestore_instance" "instance" {
  for_each = var.filestore_storage
  name     = each.value.name

  project = module.project.project_id

  location = var.gke_location
  tier     = each.value.tier

  file_shares {
    capacity_gb = each.value.capacity_gb
    name        = "filestore_share"
  }

  networks {
    network      = local.cluster_vpc.network
    modes        = ["MODE_IPV4"]
    connect_mode = "DIRECT_PEERING"
  }
}