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

output "jupyterhub_uri" {
  description = "JupyterHub Endpoint to access user interface. In case of private IP, consider port-forwarding."
  value       = var.add_auth ? "http://${module.jupyterhub.jupyterhub_uri}" : ""
}

output "jupyterhub_user" {
  description = "JupyterHub user is only required for standard authentication. Ignore, in case of IAP authentication"
  value       = module.jupyterhub.jupyterhub_user
}

output "jupyter_password" {
  description = "JupyterHub password is only required for standard authentication. Ignore, in case of IAP authentication"
  value       = module.jupyterhub.jupyterhub_password
  sensitive   = true
}

output "frontend_uri" {
  description = "RAG Frontend Endpoint to access user interface. In case of private IP, consider port-forwarding."
  value       = module.frontend.frontend_uri != "" ? "http://${module.frontend.frontend_uri}" : local.frontend_default_uri
}
