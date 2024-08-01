resource "null_resource" "kueue_manifests" {
  for_each = toset(var.enable_kueue ? ["enabled"] : [])

  provisioner "local-exec" {
    command     = <<EOT
mkdir -p ${self.triggers.manifests_dir}
wget https://github.com/kubernetes-sigs/kueue/releases/download/v${self.triggers.version}/manifests.yaml -O ${self.triggers.manifests_dir}/manifests.yaml
EOT
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }

  provisioner "local-exec" {
    command     = "rm -rf ${self.triggers.manifests_dir}"
    interpreter = ["bash", "-c"]
    when        = destroy
    working_dir = path.module
  }

  triggers = {
    manifests_dir = "${local.manifests_directory}/kueue-${var.kueue_version}"
    version       = var.kueue_version
  }
}

resource "null_resource" "kueue_manifests_apply" {
  depends_on = [
    null_resource.cluster_credentials,
    null_resource.kueue_manifests,
  ]

  for_each = toset(var.enable_kueue ? ["enabled"] : [])

  provisioner "local-exec" {
    command = "kubectl apply --server-side -f ${self.triggers.manifests_dir}/manifests.yaml"
    environment = {
      KUBECONFIG = self.triggers.kubeconfig_file
    }
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }

  provisioner "local-exec" {
    command = "kubectl delete -f ${self.triggers.manifests_dir}/manifests.yaml"
    environment = {
      KUBECONFIG = self.triggers.kubeconfig_file
    }
    interpreter = ["bash", "-c"]
    when        = destroy
    working_dir = path.module
  }

  triggers = {
    kubeconfig_file = local.kubeconfig_file
    manifests_dir   = "${local.manifests_directory}/kueue-${var.kueue_version}"
    version         = var.kueue_version
  }
}
