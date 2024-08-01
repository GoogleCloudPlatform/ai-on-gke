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
  container_cluster_folder = "${path.module}/../container_cluster"
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
