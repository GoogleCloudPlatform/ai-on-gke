# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

output "jupyter_domain" {
  value = var.jupyter_add_auth && var.jupyter_url_domain_addr == "" ? "${google_compute_global_address.jupyter_ip_address[0].address}.nip.io" : var.jupyter_url_domain_addr
}

output "frontend_domain" {
  value = var.frontend_add_auth && var.frontend_url_domain_addr == "" ? "${google_compute_global_address.frontend_ip_address[0].address}.nip.io" : var.frontend_url_domain_addr
}