/**
 * Copyright 2024 Google LLC
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

module "gke-setup" {
  source                                      = "./modules/gke-setup/"
  project_id                                  = var.project_id
  credentials_config                          = var.credentials_config
  namespace                                   = var.namespace
  namespace_create                            = var.namespace_create
  kubernetes_service_account                  = var.kubernetes_service_account
  google_service_account                      = var.google_service_account
  google_service_account_create               = var.google_service_account_create
  bucket_name                                 = var.bucket_name
  bucket_location                             = var.bucket_location
  output_bucket_name                          = var.output_bucket_name
  output_bucket_location                      = var.output_bucket_location
  benchmark_runner_kubernetes_service_account = var.benchmark_runner_kubernetes_service_account
  benchmark_runner_google_service_account     = var.benchmark_runner_google_service_account
  secret_create                               = var.secret_name == null ? false : true
  secret_name                                 = var.secret_name
  secret_location                             = var.secret_location
  nvidia_dcgm_create                          = var.nvidia_dcgm_create
  gcs_fuse_create                             = var.gcs_fuse_create
}
