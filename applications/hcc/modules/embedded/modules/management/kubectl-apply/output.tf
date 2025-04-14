/**
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

locals {
  kueue_path   = local.install_kueue ? try(var.kueue.config_path, "") : null
  kueue_content   = local.kueue_path == null ? null : file("${local.kueue_path}")
  kueue_documents = local.kueue_content == null ? null : split("---", local.kueue_content)
  decoded_documents = local.kueue_documents == null ? null : [
    for doc in local.kueue_documents
    : yamldecode(trimspace(doc)) if trimspace(doc) != "" # Remove empty documents
  ] 
  clusterqueue = local.decoded_documents == null ? null : [
    for obj in local.decoded_documents : obj if obj.kind == "ClusterQueue"][0]
  localqueue = local.decoded_documents == null ? null : [
    for obj in local.decoded_documents : obj if obj.kind == "LocalQueue"][0]
}

output "kueue_name" {
  description = "The name of the LocalQueue resource."
  value = local.localqueue == null ? null : local.localqueue.metadata.name
}
