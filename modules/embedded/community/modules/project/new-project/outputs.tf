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

output "project_name" {
  value       = module.project_factory.project_name
  description = "Name of the project that was created"
}

output "project_id" {
  value       = module.project_factory.project_id
  description = "ID of the project that was created"
}

output "project_number" {
  value       = module.project_factory.project_number
  description = "Number of the project that was created"
}

output "domain" {
  value       = module.project_factory.domain
  description = "The organization's domain"
}

output "group_email" {
  value       = module.project_factory.group_email
  description = "The email of the G Suite group with group_name"
}

output "service_account_id" {
  value       = module.project_factory.service_account_id
  description = "The id of the default service account"
}

output "service_account_display_name" {
  value       = module.project_factory.service_account_display_name
  description = "The display name of the default service account"
}

output "service_account_email" {
  value       = module.project_factory.service_account_email
  description = "The email of the default service account"
}

output "service_account_name" {
  value       = module.project_factory.service_account_name
  description = "The fully-qualified name of the default service account"
}

output "service_account_unique_id" {
  value       = module.project_factory.service_account_unique_id
  description = "The unique id of the default service account"
}

output "project_bucket_self_link" {
  value       = module.project_factory.project_bucket_self_link
  description = "Project's bucket selfLink"
}

output "project_bucket_url" {
  value       = module.project_factory.project_bucket_url
  description = "Project's bucket url"
}

output "api_s_account" {
  value       = module.project_factory.api_s_account
  description = "API service account email"
}

output "api_s_account_fmt" {
  value       = module.project_factory.api_s_account_fmt
  description = "API service account email formatted for terraform use"
}

output "enabled_apis" {
  value       = module.project_factory.enabled_apis
  description = "Enabled APIs in the project"
}

output "enabled_api_identities" {
  value       = module.project_factory.enabled_api_identities
  description = "Enabled API identities in the project"
}

output "budget_name" {
  value       = module.project_factory.budget_name
  description = "The name of the budget if created"
}
