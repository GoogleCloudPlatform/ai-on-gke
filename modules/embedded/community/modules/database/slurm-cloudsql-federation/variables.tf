/**
 * Copyright 2022 Google LLC
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

variable "authorized_networks" {
  description = "IP address ranges as authorized networks of the Cloud SQL for MySQL instances"
  type        = list(string)
  default     = []
  nullable    = false
}

variable "database_version" {
  description = "The version of the database to be created."
  type        = string
  default     = "MYSQL_5_7"
  validation {
    condition     = var.database_version == "MYSQL_5_7" || var.database_version == "MYSQL_8_0"
    error_message = "The database version must be either MYSQL_5_7 or MYSQL_8_0."
  }
}

variable "deployment_name" {
  description = "The name of the current deployment"
  type        = string
}

variable "project_id" {
  description = "Project in which the HPC deployment will be created"
  type        = string
}

variable "region" {
  description = "The region where SQL instance will be configured"
  type        = string
}

variable "tier" {
  description = "The machine type to use for the SQL instance"
  type        = string
}

variable "sql_instance_name" {
  description = "name given to the sql instance for ease of identificaion"
  type        = string
}

variable "deletion_protection" {
  description = "Whether or not to allow Terraform to destroy the instance."
  type        = string
  default     = false
}

variable "labels" {
  description = "Labels to add to the instances. Key-value pairs."
  type        = map(string)
}

variable "sql_username" {
  description = "Username for the SQL database"
  type        = string
  default     = "slurm"
}

variable "sql_password" {
  description = "Password for the SQL database."
  type        = any
  default     = null
}

variable "network_id" {
  description = <<-EOT
    The ID of the GCE VPC network to which the instance is going to be created in.:
    `projects/<project_id>/global/networks/<network_name>`"
    EOT
  type        = string
  validation {
    condition     = length(split("/", var.network_id)) == 5
    error_message = "The network id must be provided in the following format: projects/<project_id>/global/networks/<network_name>."
  }
}

variable "private_vpc_connection_peering" {
  description = "The name of the VPC Network peering connection, used only as dependency for Cloud SQL creation."
  type        = string
  default     = null
}

variable "user_managed_replication" {
  type = list(object({
    location     = string
    kms_key_name = optional(string)
  }))
  description = "Replication parameters that will be used for defined secrets"
  default     = []
}
