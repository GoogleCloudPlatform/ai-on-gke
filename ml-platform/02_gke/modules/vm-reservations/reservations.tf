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

resource "google_compute_reservation" "machine_reservation" {
  project                       = var.project_id
  specific_reservation_required = true
  name                          = format("%s-%s", var.cluster_name, "reservation")
  zone                          = var.zone
  specific_reservation {
    count = var.machine_reservation_count
    instance_properties {
      machine_type = var.machine_type
      guest_accelerators {
        accelerator_type  = var.accelerator
        accelerator_count = var.accelerator_count
      }
    }
  }
}
