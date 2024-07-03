project_id   = "$PROJECT_ID"
cluster_name = "ai-benchmark"
region       = "us-central1"
gke_location = "us-central1-a"
prefix       = "ai-benchmark"

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
  nodepool-cpu = {
    machine_type = "n2-standard-2",
  },
  nodepool-gpu = {
    ephemeral_ssd_block_config = {
      ephemeral_ssd_count = 1
    }
    machine_type = "g2-standard-16",
    guest_accelerator = {
      type  = "nvidia-l4",
      count = 1,
      gpu_driver = {
        version = "LATEST"
      }
    }
  }
}
