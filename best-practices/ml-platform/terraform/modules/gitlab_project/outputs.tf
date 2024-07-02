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

output "branch_names" {
  value = var.branches.names
}

output "branches" {
  value = var.branches.names
}

output "default_branch" {
  value = var.branches.default
}

output "full_name" {
  value = gitlab_project.project.path_with_namespace
}

output "html_url" {
  value = gitlab_project.project.web_url
}

output "http_clone_url" {
  value = gitlab_project.project.http_url_to_repo
}

output "repo" {
  sensitive = true
  value     = gitlab_project.project
}
