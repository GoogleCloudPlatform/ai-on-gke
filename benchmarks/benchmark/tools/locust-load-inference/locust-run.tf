resource "null_resource" "run_locust_tests" {

  count = var.run_test_automatically ? 1 : 0

  provisioner "local-exec" {
    working_dir = path.module
    command     = "curl -XGET http://${var.runner_endpoint_ip}:8000/run"
  }
}

locals {
  runner_templates = [
    for f in fileset(local.runner_templates_path, "*tpl") :
    "${local.runner_templates_path}/${f}"
  ]
  runner_templates_path = "${path.module}/runner-manifest-template"

  all_runner_manifests = flatten([for manifest_file in local.runner_templates :
    [for data in split("---", templatefile(manifest_file, {
      artifact_registry       = var.artifact_registry
      namespace               = var.namespace
      ksa                     = var.locust_runner_kubernetes_service_account #var.ksa #var.locust_runner_kubernetes_service_account
      project_id              = var.project_id
      bucket                  = var.output_bucket
      runner_endpoint_ip_list = var.runner_endpoint_ip == null ? [] : [var.runner_endpoint_ip]
      duration                = var.test_duration
      users                   = var.test_users
      rate                    = var.test_rate
    })) : data]
  ])
}

resource "kubernetes_manifest" "runner" {
  for_each   = toset(local.all_runner_manifests)
  depends_on = [resource.null_resource.build_and_push_runner_image]
  manifest   = yamldecode(each.value)
  timeouts {
    create = "30m"
  }
}

