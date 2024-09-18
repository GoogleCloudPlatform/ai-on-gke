# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  backend_files = [
    abspath("${path.module}/backend.tf.bucket"),
    abspath("${path.module}/../container_cluster/backend.tf"),
    abspath("${path.module}/../networking/backend.tf"),
    abspath("${path.module}/../workloads/backend.tf"),
  ]
  container_cluster_folder = "${path.module}/../container_cluster"
}

data "google_project" "environment" {
  project_id = var.environment_project_id
}

resource "google_storage_bucket" "terraform" {
  force_destroy               = false
  location                    = var.region
  name                        = local.terraform_bucket_name
  project                     = data.google_project.environment.project_id
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

resource "null_resource" "configure_nodepools_for_region" {
  provisioner "local-exec" {
    command = <<EOT
cd ${local.container_cluster_folder} && \
rm -f container_node_pool.tf && \
ln -s regions/${var.region}/container_node_pool.tf
EOT
  }
}

resource "null_resource" "write_storage_bucket" {
  for_each = toset(local.backend_files)

  provisioner "local-exec" {
    command     = <<EOT
echo "Writing 'bucket' changes to '${self.triggers.backend_file}'" && \
sed -i 's/^\([[:blank:]]*bucket[[:blank:]]*=\).*$/\1 ${jsonencode(google_storage_bucket.terraform.name)}/' ${self.triggers.backend_file}
    EOT
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }

  provisioner "local-exec" {
    when        = destroy
    command     = <<EOT
echo "Reverting 'bucket' changes in '${self.triggers.backend_file}'" && \
sed -i 's/^\([[:blank:]]*bucket[[:blank:]]*=\).*$/\1 ""/' ${self.triggers.backend_file}
    EOT
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }

  triggers = {
    backend_file = each.value
    md5          = google_storage_bucket.terraform.name
  }
}
