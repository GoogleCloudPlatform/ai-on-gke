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

module "workload-identity" {
  source                        = "./modules/workload-identity"
  count                         = var.workload_identity_create ? 1 : 0
  project_id                    = var.project_id
  credentials_config            = var.credentials_config
  namespace                     = var.namespace
  namespace_create              = var.namespace_create
  kubernetes_service_account    = var.kubernetes_service_account
  google_service_account        = var.google_service_account
  google_service_account_create = var.google_service_account_create
}

module "gcs-fuse" {
  source                 = "./modules/gcs-fuse"
  count                  = var.gcs_fuse_create ? 1 : 0
  project_id             = var.project_id
  bucket_name            = var.bucket_name
  bucket_location        = var.bucket_location
  google_service_account = module.workload-identity.0.created_resources.gsa_email
  depends_on             = [module.workload-identity]
}

module "workload-identity-runner" {
  source                        = "./modules/workload-identity"
  project_id                    = var.project_id
  credentials_config            = var.credentials_config
  namespace                     = var.namespace
  namespace_create              = false
  kubernetes_service_account    = var.benchmark_runner_kubernetes_service_account
  google_service_account        = var.benchmark_runner_google_service_account
  google_service_account_create = true
}

module "output-benchmark" {
  source                 = "./modules/output-benchmark"
  project_id             = var.project_id
  output_bucket_name     = var.output_bucket_name
  output_bucket_location = var.output_bucket_location
  google_service_account = module.workload-identity-runner.created_resources.gsa_email
  cluster_region         = var.cluster_region
  depends_on             = [module.workload-identity-runner]
}

module "nvidia-dcgm" {
  source             = "./modules/nvidia-dcgm"
  count              = var.nvidia_dcgm_create ? 1 : 0
  credentials_config = var.credentials_config
}

module "secret-manager" {
  source                 = "./modules/secret-manager"
  count                  = var.secret_create ? 1 : 0
  project_id             = var.project_id
  secret_name            = var.secret_name
  secret_location        = var.secret_location
  google_service_account = var.google_service_account # get from workload identity module if created
  depends_on             = [module.workload-identity]
}
