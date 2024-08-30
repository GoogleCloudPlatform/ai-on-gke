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

output "configsync_repository" {
  value = local.configsync_repository.html_url
}

output "git_repository" {
  value = local.git_repository
}

output "iap_domain" {
  value = local.iap_domain
}

output "ray_dashboard_url_https" {
  value = "https://${local.ray_dashboard_endpoint}"
}

output "mlflow_url_https" {
  value = "https://${local.mlflow_tracking_endpoint}"
}