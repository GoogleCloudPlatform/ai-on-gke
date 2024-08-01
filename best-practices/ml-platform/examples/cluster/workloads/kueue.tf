resource "null_resource" "kueue_manifests" {
  count = var.enable_kueue ? 1 : 0

  provisioner "local-exec" {
    command     = <<EOT
mkdir -p ${self.triggers.manifests_dir}
wget https://github.com/kubernetes-sigs/kueue/releases/download/v${self.triggers.version}/manifests.yaml -O ${self.triggers.manifests_dir}/manifests.yaml
EOT
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }

  provisioner "local-exec" {
    command     = "rm -rf ${self.triggers.configconnector_manifests_dir}"
    interpreter = ["bash", "-c"]
    when        = destroy
    working_dir = path.module
  }

  triggers = {
    manifests_dir    = "${local.manifests_directory}/kueue-${var.kueue_version}"
    version = var.kueue_version
  }
}
