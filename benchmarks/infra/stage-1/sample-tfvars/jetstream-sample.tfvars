project_id   = "PROJECT_ID"
cluster_name = "ai-benchmark"
region       = "us-east1"
gke_location = "us-east1-c"
prefix       = "ai-benchmark"
spot_vms     = true

vpc_create = {
  name             = "ai-benchmark"
  enable_cloud_nat = true
}

cluster_options = {
  enable_gcs_fuse_csi_driver            = false
  enable_gcp_filestore_csi_driver       = false
  enable_gce_persistent_disk_csi_driver = false
}

nodepools = {
  nodepool-tpu = {
    machine_type = "ct5lp-hightpu-4t",
    spot         = true,
  },
  nodepool-cpu = {
    machine_type = "n2-standard-2",
  },
}
