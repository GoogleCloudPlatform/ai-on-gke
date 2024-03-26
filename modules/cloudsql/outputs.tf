# Copyright 2024 Google LLC
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

output "instance" {
  description = "Cloud SQL Instance name"
  value       = module.cloudsql.instance_name
}

output "db_user" {
  description = "Cloud SQL instance user"
  value       = module.cloudsql.additional_users[0].name
}

output "db_password" {
  description = "Cloud SQL instance user's password"
  value       = module.cloudsql.additional_users[0].password
}
