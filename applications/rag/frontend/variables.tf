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

variable "project_id" {
  type        = string
  description = "GCP project id"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace where resources are deployed"
  default     = "rag"
}

variable "region" {
  type        = string
  description = "GCP project region"
  default     = "us-central1"
}

variable "db_secret_name" {
  type        = string
  description = "CloudSQL user"
}

variable "db_secret_namespace" {
  type        = string
  description = "CloudSQL password"
  default = "rag"
}

variable "dataset_embeddings_table_name" {
  type        = string
  description = "Name of the table that stores vector embeddings for input dataset"
}

variable "inference_service_name" {
  type        = string
  description = "Model inference k8s service name"
}

variable "inference_service_namespace" {
  type        = string
  description = "Model inference k8s service endpoint"
  default = "rag"
}

variable "create_service_account" {
  type        = bool
  description = "Creates a google service account & k8s service account & configures workload identity"
  default     = true
}

variable "google_service_account" {
  type        = string
  description = "Google Service Account name"
  default = "frontend-gcp-sa"
}