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
  backend_file             = "../backend.tf"
  project_id_prefix        = "${var.project.name}-${var.environment_name}"
  project_id_suffix_length = 29 - length(local.project_id_prefix)
  tfvars_file              = "../mlp.auto.tfvars"
}

resource "random_string" "project_id_suffix" {
  length  = local.project_id_suffix_length
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "google_project" "environment" {
  billing_account = var.project.billing_account_id
  folder_id       = var.project.folder_id == "" ? null : var.project.folder_id
  name            = local.project_id_prefix
  org_id          = var.project.org_id == "" ? null : var.project.org_id
  project_id      = "${local.project_id_prefix}-${random_string.project_id_suffix.result}"
}


resource "google_storage_bucket" "mlp" {
  force_destroy               = false
  location                    = var.storage_bucket_location
  name                        = "${google_project.environment.project_id}-mlp"
  project                     = google_project.environment.project_id
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

resource "null_resource" "write_environment_name" {
  triggers = {
    md5         = var.environment_name
    tfvars_file = local.tfvars_file
  }

  provisioner "local-exec" {
    command     = <<EOT
echo "Writing 'environment_name' changes to '${local.tfvars_file}'" && \
sed -i 's/^\([[:blank:]]*environment_name[[:blank:]]*=\).*$/\1 ${jsonencode(var.environment_name)}/' ${local.tfvars_file}
    EOT
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }

  provisioner "local-exec" {
    when        = destroy
    command     = <<EOT
echo "Reverting 'environment_name' changes in '${self.triggers.tfvars_file}'" && \
sed -i 's/^\([[:blank:]]*environment_name[[:blank:]]*=\).*$/\1 "dev"/' ${self.triggers.tfvars_file}
    EOT
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }
}

resource "null_resource" "write_project_id" {
  triggers = {
    md5         = google_project.environment.project_id
    tfvars_file = local.tfvars_file
  }

  provisioner "local-exec" {
    command     = <<EOT
echo "Writing 'project.id' changes to '${local.tfvars_file}'" && \
sed -i 's/^\([[:blank:]]*environment_project_id[[:blank:]]*=\).*$/\1 ${jsonencode(google_project.environment.project_id)}/' ${local.tfvars_file}
    EOT
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }

  provisioner "local-exec" {
    when        = destroy
    command     = <<EOT
echo "Reverting 'project.id' changes in '${self.triggers.tfvars_file}'" && \
sed -i 's/^\([[:blank:]]*environment_project_id[[:blank:]]*=\).*$/\1 "YOUR_PROJECT_ID"/' ${self.triggers.tfvars_file}
    EOT
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }
}

resource "null_resource" "write_storage_bucket" {
  triggers = {
    backend_file = local.backend_file
    md5          = google_storage_bucket.mlp.name
  }

  provisioner "local-exec" {
    command     = <<EOT
echo "Writing 'bucket' changes to '${local.backend_file}'" && \
sed -i 's/^\([[:blank:]]*bucket[[:blank:]]*=\).*$/\1 ${jsonencode(google_storage_bucket.mlp.name)}/' ${local.backend_file} && \
sed -i 's/^\([[:blank:]]*bucket[[:blank:]]*=\).*$/\1 ${jsonencode(google_storage_bucket.mlp.name)}/' backend.tf.bucket && \
mv backend.tf backend.tf.local && \
cp backend.tf.bucket backend.tf
    EOT
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }

  provisioner "local-exec" {
    when        = destroy
    command     = <<EOT
echo "Reverting 'bucket' changes in '${self.triggers.backend_file}'" && \
sed -i 's/^\([[:blank:]]*bucket[[:blank:]]*=\).*$/\1 "YOUR_STATE_BUCKET"/' ${self.triggers.backend_file} && \
sed -i 's/^\([[:blank:]]*bucket[[:blank:]]*=\).*$/\1 ""/' backend.tf.bucket
    EOT
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }
}
