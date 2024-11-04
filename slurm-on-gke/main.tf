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

module "slurm-cluster-001" {
  source           = "../modules/slurm-cluster/"
  namespace        = "slurm"
  namespace_create = true

  cluster_config = var.config
}

module "slurm-workers-001" {
  source = "../modules/slurm-nodeset"
  name   = "slurmd"
  config = {
    type      = "g2-standard-4"
    instances = 2
    namespace = module.slurm-cluster-001.namespace
    image     = var.config.image
  }
}

module "slurm-workers-002" {
  source = "../modules/slurm-nodeset"
  name   = "slurmd1"
  config = {
    type      = "n1-standard-8"
    instances = 1
    namespace = module.slurm-cluster-001.namespace
    image     = var.config.image
    accelerator = {
      type  = "nvidia-tesla-t4"
      count = 2
    }
  }
}
