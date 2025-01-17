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

# TEMPLATE
module "slurm_login_template" {
  source = "github.com/GoogleCloudPlatform/slurm-gcp.git//terraform/slurm_cluster/modules/slurm_instance_template?ref=6.8.2"

  for_each = { for x in var.login_nodes : x.name_prefix => x }

  project_id          = var.project_id
  slurm_cluster_name  = local.slurm_cluster_name
  slurm_instance_role = "login"
  slurm_bucket_path   = module.slurm_files.slurm_bucket_path
  name_prefix         = each.value.name_prefix

  additional_disks         = each.value.additional_disks
  bandwidth_tier           = each.value.bandwidth_tier
  can_ip_forward           = each.value.can_ip_forward
  disable_smt              = each.value.disable_smt
  disk_auto_delete         = each.value.disk_auto_delete
  disk_labels              = each.value.disk_labels
  disk_size_gb             = each.value.disk_size_gb
  disk_type                = each.value.disk_type
  enable_confidential_vm   = each.value.enable_confidential_vm
  enable_oslogin           = each.value.enable_oslogin
  enable_shielded_vm       = each.value.enable_shielded_vm
  gpu                      = each.value.gpu
  labels                   = each.value.labels
  machine_type             = each.value.machine_type
  metadata                 = merge(each.value.metadata, local.universe_domain)
  min_cpu_platform         = each.value.min_cpu_platform
  on_host_maintenance      = each.value.on_host_maintenance
  preemptible              = each.value.preemptible
  region                   = each.value.region
  service_account          = each.value.service_account
  shielded_instance_config = each.value.shielded_instance_config
  source_image_family      = each.value.source_image_family
  source_image_project     = each.value.source_image_project
  source_image             = each.value.source_image
  spot                     = each.value.spot
  subnetwork               = each.value.subnetwork
  tags                     = concat([local.slurm_cluster_name], each.value.tags)
  termination_action       = each.value.termination_action
}

# INSTANCE
module "slurm_login_instance" {
  source   = "github.com/GoogleCloudPlatform/slurm-gcp.git//terraform/slurm_cluster/modules/_slurm_instance?ref=6.8.2"
  for_each = { for x in var.login_nodes : x.name_prefix => x }

  access_config       = each.value.access_config
  add_hostname_suffix = true
  hostname            = "${local.slurm_cluster_name}-${each.key}"
  slurm_instance_role = "login"

  project_id         = var.project_id
  slurm_cluster_name = local.slurm_cluster_name

  instance_template = module.slurm_login_template[each.key].self_link
  labels            = each.value.labels
  num_instances     = each.value.num_instances

  additional_networks = each.value.additional_networks
  region              = each.value.region
  static_ips          = each.value.static_ips
  subnetwork          = each.value.subnetwork
  zone                = each.value.zone

  # trigger replacement of login nodes when the controller instance is replaced
  replace_trigger = module.slurm_controller_instance.instances_self_links[0]
}
