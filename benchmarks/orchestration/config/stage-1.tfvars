project_id              = "example-project-id"
cluster_name            = "test-00"
region                  = "us-central1"
gke_location            = "us-central1-a"
enable_private_endpoint = false

vpc_create = {
  enable_cloud_nat = true
}

cluster_options = {
  enable_gcs_fuse_csi_driver            = true
  enable_gcp_filestore_csi_driver       = true
  enable_gce_persistent_disk_csi_driver = true
}

nodepools = {
  nodepool-cpu = {
    machine_type = "n2-standard-2",
  },
  nodepool-gpu = {
    machine_type = "g2-standard-4",
    guest_accelerator = {
      type  = "nvidia-l4",
      count = 1,
      gpu_driver = {
        version = "LATEST"
      }
    }
  }
}

