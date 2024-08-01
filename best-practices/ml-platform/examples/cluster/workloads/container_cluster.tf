resource "null_resource" "cluster_credentials" {
  provisioner "local-exec" {
    command     = <<EOT
KUBECONFIG=${self.triggers.kubeconfig_file} gcloud container clusters get-credentials ${local.cluster_name} --location ${var.region}
EOT
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }

  provisioner "local-exec" {
    command     = "rm -rf ${self.triggers.kubeconfig_file}"
    interpreter = ["bash", "-c"]
    when        = destroy
    working_dir = path.module
  }

  triggers = {
    kubeconfig_file = local.kubeconfig_file
  }
}
