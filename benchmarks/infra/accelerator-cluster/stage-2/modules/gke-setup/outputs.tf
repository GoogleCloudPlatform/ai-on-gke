output "created_resources" {
  description = "IDs of the resources created, if any."
  value = merge(
    var.secret_create == true ? module.secret-manager[0].created_resources : {},
    #var.gcs_fuse_create == true ? module.gcs-fuse[0].created_resources : {},
    var.workload_identity_create == true ? module.workload-identity[0].created_resources : {},
    #var.nvidia_dcgm_create == true ? module.nvidia-dcgm.created_resources : {}
    module.output-benchmark.created_resources,
  )
}
