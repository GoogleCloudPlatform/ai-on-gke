## Description

> [!NOTE]
> Slurm-gcp-v5-node-group module is deprecated. See
> [this update](../../../../examples/README.md#completed-migration-to-slurm-gcp-v6)
> for specific recommendations and timelines.

This module creates a node group data structure intended to be input to the
[schedmd-slurm-gcp-v5-partition](../schedmd-slurm-gcp-v5-partition/) module.

Node groups allow adding heterogeneous node types to a partition, and hence
running jobs that mix multiple node characteristics. See the [heterogeneous jobs
section][hetjobs] of the SchedMD documentation for more information.

To specify nodes from a specific node group in a partition, the [`--nodelist`]
(or `-w`) flag can be used, for example:

```bash
srun -N 3 -p compute --nodelist cluster-compute-group-[0-2] hostname
```

Where the 3 nodes will be selected from the nodes `cluster-compute-group-[0-2]`
in the compute partition.

Additionally, depending on how the nodes differ, a constraint can be added via
the [`--constraint`] (or `-C`) flag or other flags such as `--mincpus` can be
used to specify nodes with the desired characteristics.

[`--nodelist`]: https://slurm.schedmd.com/srun.html#OPT_nodelist
[`--constraint`]: https://slurm.schedmd.com/srun.html#OPT_constraint
[hetjobs]: https://slurm.schedmd.com/heterogeneous_jobs.html

### Example

The following code snippet creates a partition module using the `node-group`
module as input with:

* a max node count of 200
* VM machine type of `c2-standard-30`
* partition name of "compute"
* default group name of "ghpc"
* connected to the `network1` module via `use`
* nodes mounted to homefs via `use`

```yaml
- id: node_group
  source: community/modules/compute/schedmd-slurm-gcp-v5-node-group
  settings:
    node_count_dynamic_max: 200
    machine_type: c2-standard-30

- id: compute_partition
  source: community/modules/compute/schedmd-slurm-gcp-v5-partition
  use:
  - network1
  - homefs
  - node_group
  settings:
    partition_name: compute
```

## Custom Images

For more information on creating valid custom images for the node group VM
instances or for custom instance templates, see our [vm-images.md] documentation
page.

[vm-images.md]: ../../../../docs/vm-images.md#slurm-on-gcp-custom-images

## GPU Support

More information on GPU support in Slurm on GCP and other Cluster Toolkit modules
can be found at [docs/gpu-support.md](../../../../docs/gpu-support.md)

## Support
The Cluster Toolkit team maintains the wrapper around the [slurm-on-gcp] terraform
modules. For support with the underlying modules, see the instructions in the
[slurm-gcp README][slurm-gcp-readme].

[slurm-on-gcp]: https://github.com/GoogleCloudPlatform/slurm-gcp
[slurm-gcp-readme]: https://github.com/GoogleCloudPlatform/slurm-gcp#slurm-on-google-cloud-platform

## License
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
Copyright 2023 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.1 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.11 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 5.11 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_default_service_account.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_default_service_account) | data source |
| [google_compute_image.slurm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_image) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_config"></a> [access\_config](#input\_access\_config) | Access configurations, i.e. IPs via which the node group instances can be accessed via the internet. | <pre>list(object({<br/>    nat_ip       = string<br/>    network_tier = string<br/>  }))</pre> | `[]` | no |
| <a name="input_additional_disks"></a> [additional\_disks](#input\_additional\_disks) | Configurations of additional disks to be included on the partition nodes. | <pre>list(object({<br/>    disk_name    = string<br/>    device_name  = string<br/>    disk_size_gb = number<br/>    disk_type    = string<br/>    disk_labels  = map(string)<br/>    auto_delete  = bool<br/>    boot         = bool<br/>  }))</pre> | `[]` | no |
| <a name="input_additional_networks"></a> [additional\_networks](#input\_additional\_networks) | Additional network interface details for GCE, if any. | <pre>list(object({<br/>    network            = string<br/>    subnetwork         = string<br/>    subnetwork_project = string<br/>    network_ip         = string<br/>    nic_type           = string<br/>    stack_type         = string<br/>    queue_count        = number<br/>    access_config = list(object({<br/>      nat_ip       = string<br/>      network_tier = string<br/>    }))<br/>    ipv6_access_config = list(object({<br/>      network_tier = string<br/>    }))<br/>    alias_ip_range = list(object({<br/>      ip_cidr_range         = string<br/>      subnetwork_range_name = string<br/>    }))<br/>  }))</pre> | `[]` | no |
| <a name="input_allow_automatic_updates"></a> [allow\_automatic\_updates](#input\_allow\_automatic\_updates) | If false, disables automatic system package updates on the created instances.  This feature is<br/>only available on supported images (or images derived from them).  For more details, see<br/>https://cloud.google.com/compute/docs/instances/create-hpc-vm#disable_automatic_updates | `bool` | `true` | no |
| <a name="input_bandwidth_tier"></a> [bandwidth\_tier](#input\_bandwidth\_tier) | Configures the network interface card and the maximum egress bandwidth for VMs.<br/>  - Setting `platform_default` respects the Google Cloud Platform API default values for networking.<br/>  - Setting `virtio_enabled` explicitly selects the VirtioNet network adapter.<br/>  - Setting `gvnic_enabled` selects the gVNIC network adapter (without Tier 1 high bandwidth).<br/>  - Setting `tier_1_enabled` selects both the gVNIC adapter and Tier 1 high bandwidth networking.<br/>  - Note: both gVNIC and Tier 1 networking require a VM image with gVNIC support as well as specific VM families and shapes.<br/>  - See [official docs](https://cloud.google.com/compute/docs/networking/configure-vm-with-high-bandwidth-configuration) for more details. | `string` | `"platform_default"` | no |
| <a name="input_can_ip_forward"></a> [can\_ip\_forward](#input\_can\_ip\_forward) | Enable IP forwarding, for NAT instances for example. | `bool` | `false` | no |
| <a name="input_disable_public_ips"></a> [disable\_public\_ips](#input\_disable\_public\_ips) | If set to false. The node group VMs will have a random public IP assigned to it. Ignored if access\_config is set. | `bool` | `true` | no |
| <a name="input_disk_auto_delete"></a> [disk\_auto\_delete](#input\_disk\_auto\_delete) | Whether or not the boot disk should be auto-deleted. | `bool` | `true` | no |
| <a name="input_disk_labels"></a> [disk\_labels](#input\_disk\_labels) | Labels specific to the boot disk. These will be merged with var.labels. | `map(string)` | `{}` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Size of boot disk to create for the partition compute nodes. | `number` | `50` | no |
| <a name="input_disk_type"></a> [disk\_type](#input\_disk\_type) | Boot disk type. | `string` | `"pd-standard"` | no |
| <a name="input_enable_confidential_vm"></a> [enable\_confidential\_vm](#input\_enable\_confidential\_vm) | Enable the Confidential VM configuration. Note: the instance image must support option. | `bool` | `false` | no |
| <a name="input_enable_oslogin"></a> [enable\_oslogin](#input\_enable\_oslogin) | Enables Google Cloud os-login for user login and authentication for VMs.<br/>See https://cloud.google.com/compute/docs/oslogin | `bool` | `true` | no |
| <a name="input_enable_shielded_vm"></a> [enable\_shielded\_vm](#input\_enable\_shielded\_vm) | Enable the Shielded VM configuration. Note: the instance image must support option. | `bool` | `false` | no |
| <a name="input_enable_smt"></a> [enable\_smt](#input\_enable\_smt) | Enables Simultaneous Multi-Threading (SMT) on instance. | `bool` | `false` | no |
| <a name="input_enable_spot_vm"></a> [enable\_spot\_vm](#input\_enable\_spot\_vm) | Enable the partition to use spot VMs (https://cloud.google.com/spot-vms). | `bool` | `false` | no |
| <a name="input_gpu"></a> [gpu](#input\_gpu) | DEPRECATED: use var.guest\_accelerator | <pre>object({<br/>    type  = string<br/>    count = number<br/>  })</pre> | `null` | no |
| <a name="input_guest_accelerator"></a> [guest\_accelerator](#input\_guest\_accelerator) | List of the type and count of accelerator cards attached to the instance. | <pre>list(object({<br/>    type  = string,<br/>    count = number<br/>  }))</pre> | `[]` | no |
| <a name="input_instance_image"></a> [instance\_image](#input\_instance\_image) | Defines the image that will be used in the Slurm node group VM instances.<br/><br/>Expected Fields:<br/>name: The name of the image. Mutually exclusive with family.<br/>family: The image family to use. Mutually exclusive with name.<br/>project: The project where the image is hosted.<br/><br/>For more information on creating custom images that comply with Slurm on GCP<br/>see the "Slurm on GCP Custom Images" section in docs/vm-images.md. | `map(string)` | <pre>{<br/>  "family": "slurm-gcp-5-12-hpc-centos-7",<br/>  "project": "schedmd-slurm-public"<br/>}</pre> | no |
| <a name="input_instance_image_custom"></a> [instance\_image\_custom](#input\_instance\_image\_custom) | A flag that designates that the user is aware that they are requesting<br/>to use a custom and potentially incompatible image for this Slurm on<br/>GCP module.<br/><br/>If the field is set to false, only the compatible families and project<br/>names will be accepted.  The deployment will fail with any other image<br/>family or name.  If set to true, no checks will be done.<br/><br/>See: https://goo.gle/hpc-slurm-images | `bool` | `false` | no |
| <a name="input_instance_template"></a> [instance\_template](#input\_instance\_template) | Self link to a custom instance template. If set, other VM definition<br/>variables such as machine\_type and instance\_image will be ignored in favor<br/>of the provided instance template.<br/><br/>For more information on creating custom images for the instance template<br/>that comply with Slurm on GCP see the "Slurm on GCP Custom Images" section<br/>in docs/vm-images.md. | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to add to partition compute instances. Key-value pairs. | `map(string)` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | Compute Platform machine type to use for this partition compute nodes. | `string` | `"c2-standard-60"` | no |
| <a name="input_maintenance_interval"></a> [maintenance\_interval](#input\_maintenance\_interval) | Specifies the frequency of planned maintenance events. Must be "PERIODIC" or empty string to not use this feature. | `string` | `""` | no |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | Metadata, provided as a map. | `map(string)` | `{}` | no |
| <a name="input_min_cpu_platform"></a> [min\_cpu\_platform](#input\_min\_cpu\_platform) | The name of the minimum CPU platform that you want the instance to use. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the node group. | `string` | `"ghpc"` | no |
| <a name="input_node_conf"></a> [node\_conf](#input\_node\_conf) | Map of Slurm node line configuration. | `map(any)` | `{}` | no |
| <a name="input_node_count_dynamic_max"></a> [node\_count\_dynamic\_max](#input\_node\_count\_dynamic\_max) | Maximum number of auto-scaling nodes allowed in this partition. | `number` | `10` | no |
| <a name="input_node_count_static"></a> [node\_count\_static](#input\_node\_count\_static) | Number of nodes to be statically created. | `number` | `0` | no |
| <a name="input_on_host_maintenance"></a> [on\_host\_maintenance](#input\_on\_host\_maintenance) | Instance availability Policy.<br/><br/>Note: Placement groups are not supported when on\_host\_maintenance is set to<br/>"MIGRATE" and will be deactivated regardless of the value of<br/>enable\_placement. To support enable\_placement, ensure on\_host\_maintenance is<br/>set to "TERMINATE". | `string` | `"TERMINATE"` | no |
| <a name="input_preemptible"></a> [preemptible](#input\_preemptible) | Should use preemptibles to burst. | `bool` | `false` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project in which the HPC deployment will be created. | `string` | n/a | yes |
| <a name="input_reservation_name"></a> [reservation\_name](#input\_reservation\_name) | Name of the reservation to use for VM resources<br/>- Must be a "SPECIFIC" reservation<br/>- Set to empty string if using no reservation or automatically-consumed reservations | `string` | `""` | no |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | Service account to attach to the compute instances. If not set, the<br/>default compute service account for the given project will be used with the<br/>"https://www.googleapis.com/auth/cloud-platform" scope. | <pre>object({<br/>    email  = string<br/>    scopes = set(string)<br/>  })</pre> | `null` | no |
| <a name="input_shielded_instance_config"></a> [shielded\_instance\_config](#input\_shielded\_instance\_config) | Shielded VM configuration for the instance. Note: not used unless<br/>enable\_shielded\_vm is 'true'.<br/>- enable\_integrity\_monitoring : Compare the most recent boot measurements to the<br/>  integrity policy baseline and return a pair of pass/fail results depending on<br/>  whether they match or not.<br/>- enable\_secure\_boot : Verify the digital signature of all boot components, and<br/>  halt the boot process if signature verification fails.<br/>- enable\_vtpm : Use a virtualized trusted platform module, which is a<br/>  specialized computer chip you can use to encrypt objects like keys and<br/>  certificates. | <pre>object({<br/>    enable_integrity_monitoring = bool<br/>    enable_secure_boot          = bool<br/>    enable_vtpm                 = bool<br/>  })</pre> | <pre>{<br/>  "enable_integrity_monitoring": true,<br/>  "enable_secure_boot": true,<br/>  "enable_vtpm": true<br/>}</pre> | no |
| <a name="input_source_image"></a> [source\_image](#input\_source\_image) | DEPRECATED: Use `instance_image` instead. | `string` | `null` | no |
| <a name="input_source_image_family"></a> [source\_image\_family](#input\_source\_image\_family) | DEPRECATED: Use `instance_image` instead. | `string` | `null` | no |
| <a name="input_source_image_project"></a> [source\_image\_project](#input\_source\_image\_project) | DEPRECATED: Use `instance_image` instead. | `string` | `null` | no |
| <a name="input_spot_instance_config"></a> [spot\_instance\_config](#input\_spot\_instance\_config) | Configuration for spot VMs. | <pre>object({<br/>    termination_action = string<br/>  })</pre> | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Network tag list. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_node_groups"></a> [node\_groups](#output\_node\_groups) | Details of the node group. Typically used as input to `schedmd-slurm-gcp-v5-partition`. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
