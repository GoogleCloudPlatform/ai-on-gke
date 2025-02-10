/**
  * Copyright 2023 Google LLC
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
  * You may obtain a copy of the License at
  *
  *      http://www.apache.org/licenses/LICENSE-2.0
  *
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the License is distributed on an "AS IS" BASIS,
  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  * See the License for the specific language governing permissions and
  * limitations under the License.
  */

output "gke_cluster" {
  description = "Link to GKE cluster"
  value       = "https://pantheon.corp.google.com/kubernetes/clusters/details/${local.region}/${var.goog_cm_deployment_name}"
}

output "result_bucket" {
  description = "Link to result GCS bucket"
  value       = "https://pantheon.corp.google.com/storage/browser/${local.result_bucket_name}"
}
