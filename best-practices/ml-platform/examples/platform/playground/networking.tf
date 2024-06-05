# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module "create-vpc" {
  source = "../../../terraform/modules/network"

  depends_on = [
    google_project_service.compute_googleapis_com
  ]

  network_name     = format("%s-%s", var.network_name, var.environment_name)
  project_id       = data.google_project.environment.project_id
  routing_mode     = var.routing_mode
  subnet_01_ip     = var.subnet_01_ip
  subnet_01_name   = format("%s-%s", var.subnet_01_name, var.environment_name)
  subnet_01_region = var.subnet_01_region
}

module "cloud-nat" {
  source = "../../../terraform/modules/cloud-nat"

  create_router = true
  name          = format("%s-%s", "nat-for-acm", var.environment_name)
  network       = module.create-vpc.vpc
  project_id    = data.google_project.environment.project_id
  region        = split("/", module.create-vpc.subnet-1)[3]
  router        = format("%s-%s", "router-for-acm", var.environment_name)
}