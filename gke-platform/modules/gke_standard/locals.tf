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


locals {
  # "machine_configs" is a map from pre-configured machine config name
  # to GPU/CPU/DISK combination. This is to solve problems like "Machines
  # with L4 GPU must not use pd-standard" or "Machines with L4 GPU must
  # use G2 CPU".
  machine_configs = {
    nvidia_l4_x1 = {
      machine = "g2-standard-16"
      gpu = "nvidia-l4"
      count = 1
      disk = "pd-balanced"
    }
    nvidia_l4_x2 = {
      machine = "g2-standard-24"
      gpu = "nvidia-l4"
      count = 2
      disk = "pd-balanced"
    }
    nvidia_l4_x4 = {
      machine = "g2-standard-48"
      gpu = "nvidia-l4"
      count = 4
      disk = "pd-balanced"
    }
    nvidia_l4_x8 = {
      machine = "g2-standard-96"
      gpu = "nvidia-l4"
      count = 8
      disk = "pd-balanced"
    }
    nvidia_t4_x1 = {
      machine = "n1-standard-8"
      gpu = "nvidia-tesla-t4"
      count = 1
      disk = "pd-standard"
    }
    nvidia_t4_x2 = {
      machine = "n1-standard-16"
      gpu = "nvidia-tesla-t4"
      count = 2
      disk = "pd-standard"
    }
    nvidia_t4_x4 = {
      machine = "n1-standard-32"
      gpu = "nvidia-tesla-t4"
      count = 4
      disk = "pd-standard"
    }
    custom_gpu = {
      machine = var.custom_gpu_selection.machine
      gpu = var.custom_gpu_selection.gpu
      count = var.custom_gpu_selection.count
      disk = var.custom_gpu_selection.disk
    }
  }
  gpu_type  = lookup(local.machine_configs, var.gpu_pool_machine_cfg).gpu
  gpu_count = lookup(local.machine_configs, var.gpu_pool_machine_cfg).count
  gpu_pool_machine_type = lookup(local.machine_configs, var.gpu_pool_machine_cfg).machine
  gpu_pool_disk_type = lookup(local.machine_configs, var.gpu_pool_machine_cfg).disk
}
