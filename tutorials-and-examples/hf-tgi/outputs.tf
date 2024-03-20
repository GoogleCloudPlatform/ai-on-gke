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

output "inference_service_name" {
  description = "Name of model inference service"
  value       = kubernetes_service.inference_service.metadata[0].name
}

output "inference_service_namespace" {
  description = "Namespace of model inference service"
  value       = kubernetes_service.inference_service.metadata[0].namespace
}

output "inference_service_endpoint" {
  description = "Endpoint of model inference service"
  value       = kubernetes_service.inference_service.status != null ? (kubernetes_service.inference_service.status[0].load_balancer != null ? "${kubernetes_service.inference_service.status[0].load_balancer[0].ingress[0].ip}" : "") : ""
}
