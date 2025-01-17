## Description

This module creates an instance template to be used by dynamic nodes,
also it creates a nodeset data structure intended to be input to the
[schedmd-slurm-gcp-v6-partition](../schedmd-slurm-gcp-v6-partition/) module.

### Example

The following code snippet creates an instance template to be used by MIG.

```yaml
  - id: dynamic_ns
    source: community/modules/compute/schedmd-slurm-gcp-v6-nodeset-dynamic
    use: [network, controller]
    settings:
      machine_type: n2-standard-2

  - id: dynamic_partition
    source: community/modules/compute/schedmd-slurm-gcp-v6-partition
    use: [dynamic_ns]
    settings:
      partition_name: mp
      is_default: true

  - id: controller
    source: community/modules/scheduler/schedmd-slurm-gcp-v6-controller
    use: [network, dynamic_partition]

  - id: mig
    source: community/modules/compute/mig
    settings:
      versions:
      - name: highlander # there can be only one
        instance_template: $(dynamic_ns.instance_template_self_link)
      base_instance_name: $(dynamic_ns.node_name_prefix)
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

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.11 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 5.11 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_slurm_nodeset_template"></a> [slurm\_nodeset\_template](#module\_slurm\_nodeset\_template) | github.com/GoogleCloudPlatform/slurm-gcp.git//terraform/slurm_cluster/modules/slurm_instance_template | 6.8.2 |

## Resources

| Name | Type |
|------|------|
| [google_compute_image.slurm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_image) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_config"></a> [access\_config](#input\_access\_config) | Access configurations, i.e. IPs via which the VM instance can be accessed via the Internet. | <pre>list(object({<br/>    nat_ip       = string<br/>    network_tier = string<br/>  }))</pre> | `[]` | no |
| <a name="input_additional_disks"></a> [additional\_disks](#input\_additional\_disks) | Configurations of additional disks to be included on the partition nodes. (do not use "disk\_type: local-ssd"; known issue being addressed) | <pre>list(object({<br/>    disk_name    = string<br/>    device_name  = string<br/>    disk_size_gb = number<br/>    disk_type    = string<br/>    disk_labels  = map(string)<br/>    auto_delete  = bool<br/>    boot         = bool<br/>  }))</pre> | `[]` | no |
| <a name="input_additional_networks"></a> [additional\_networks](#input\_additional\_networks) | Additional network interface details for GCE, if any. | <pre>list(object({<br/>    network            = string<br/>    subnetwork         = string<br/>    subnetwork_project = string<br/>    network_ip         = string<br/>    nic_type           = string<br/>    stack_type         = string<br/>    queue_count        = number<br/>    access_config = list(object({<br/>      nat_ip       = string<br/>      network_tier = string<br/>    }))<br/>    ipv6_access_config = list(object({<br/>      network_tier = string<br/>    }))<br/>    alias_ip_range = list(object({<br/>      ip_cidr_range         = string<br/>      subnetwork_range_name = string<br/>    }))<br/>  }))</pre> | `[]` | no |
| <a name="input_allow_automatic_updates"></a> [allow\_automatic\_updates](#input\_allow\_automatic\_updates) | If false, disables automatic system package updates on the created instances.  This feature is<br/>only available on supported images (or images derived from them).  For more details, see<br/>https://cloud.google.com/compute/docs/instances/create-hpc-vm#disable_automatic_updates | `bool` | `true` | no |
| <a name="input_bandwidth_tier"></a> [bandwidth\_tier](#input\_bandwidth\_tier) | Configures the network interface card and the maximum egress bandwidth for VMs.<br/>  - Setting `platform_default` respects the Google Cloud Platform API default values for networking.<br/>  - Setting `virtio_enabled` explicitly selects the VirtioNet network adapter.<br/>  - Setting `gvnic_enabled` selects the gVNIC network adapter (without Tier 1 high bandwidth).<br/>  - Setting `tier_1_enabled` selects both the gVNIC adapter and Tier 1 high bandwidth networking.<br/>  - Note: both gVNIC and Tier 1 networking require a VM image with gVNIC support as well as specific VM families and shapes.<br/>  - See [official docs](https://cloud.google.com/compute/docs/networking/configure-vm-with-high-bandwidth-configuration) for more details. | `string` | `"platform_default"` | no |
| <a name="input_can_ip_forward"></a> [can\_ip\_forward](#input\_can\_ip\_forward) | Enable IP forwarding, for NAT instances for example. | `bool` | `false` | no |
| <a name="input_disk_auto_delete"></a> [disk\_auto\_delete](#input\_disk\_auto\_delete) | Whether or not the boot disk should be auto-deleted. | `bool` | `true` | no |
| <a name="input_disk_labels"></a> [disk\_labels](#input\_disk\_labels) | Labels specific to the boot disk. These will be merged with var.labels. | `map(string)` | `{}` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Size of boot disk to create for the partition compute nodes. | `number` | `50` | no |
| <a name="input_disk_type"></a> [disk\_type](#input\_disk\_type) | Boot disk type, can be either hyperdisk-balanced, pd-ssd, pd-standard, pd-balanced, or pd-extreme. | `string` | `"pd-standard"` | no |
| <a name="input_enable_confidential_vm"></a> [enable\_confidential\_vm](#input\_enable\_confidential\_vm) | Enable the Confidential VM configuration. Note: the instance image must support option. | `bool` | `false` | no |
| <a name="input_enable_oslogin"></a> [enable\_oslogin](#input\_enable\_oslogin) | Enables Google Cloud os-login for user login and authentication for VMs.<br/>See https://cloud.google.com/compute/docs/oslogin | `bool` | `true` | no |
| <a name="input_enable_public_ips"></a> [enable\_public\_ips](#input\_enable\_public\_ips) | If set to true. The node group VMs will have a random public IP assigned to it. Ignored if access\_config is set. | `bool` | `false` | no |
| <a name="input_enable_shielded_vm"></a> [enable\_shielded\_vm](#input\_enable\_shielded\_vm) | Enable the Shielded VM configuration. Note: the instance image must support option. | `bool` | `false` | no |
| <a name="input_enable_smt"></a> [enable\_smt](#input\_enable\_smt) | Enables Simultaneous Multi-Threading (SMT) on instance. | `bool` | `false` | no |
| <a name="input_enable_spot_vm"></a> [enable\_spot\_vm](#input\_enable\_spot\_vm) | Enable the partition to use spot VMs (https://cloud.google.com/spot-vms). | `bool` | `false` | no |
| <a name="input_feature"></a> [feature](#input\_feature) | The node feature, used to bind nodes to the nodeset. If not set, the nodeset name will be used. | `string` | `null` | no |
| <a name="input_guest_accelerator"></a> [guest\_accelerator](#input\_guest\_accelerator) | List of the type and count of accelerator cards attached to the instance. | <pre>list(object({<br/>    type  = string,<br/>    count = number<br/>  }))</pre> | `[]` | no |
| <a name="input_instance_image"></a> [instance\_image](#input\_instance\_image) | Defines the image that will be used in the Slurm node group VM instances.<br/><br/>Expected Fields:<br/>name: The name of the image. Mutually exclusive with family.<br/>family: The image family to use. Mutually exclusive with name.<br/>project: The project where the image is hosted.<br/><br/>For more information on creating custom images that comply with Slurm on GCP<br/>see the "Slurm on GCP Custom Images" section in docs/vm-images.md. | `map(string)` | <pre>{<br/>  "family": "slurm-gcp-6-7-hpc-rocky-linux-8",<br/>  "project": "schedmd-slurm-public"<br/>}</pre> | no |
| <a name="input_instance_image_custom"></a> [instance\_image\_custom](#input\_instance\_image\_custom) | A flag that designates that the user is aware that they are requesting<br/>to use a custom and potentially incompatible image for this Slurm on<br/>GCP module.<br/><br/>If the field is set to false, only the compatible families and project<br/>names will be accepted.  The deployment will fail with any other image<br/>family or name.  If set to true, no checks will be done.<br/><br/>See: https://goo.gle/hpc-slurm-images | `bool` | `false` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to add to partition compute instances. Key-value pairs. | `map(string)` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | Compute Platform machine type to use for this partition compute nodes. | `string` | `"c2-standard-60"` | no |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | Metadata, provided as a map. | `map(string)` | `{}` | no |
| <a name="input_min_cpu_platform"></a> [min\_cpu\_platform](#input\_min\_cpu\_platform) | The name of the minimum CPU platform that you want the instance to use. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the nodeset. Automatically populated by the module id if not set.<br/>If setting manually, ensure a unique value across all nodesets. | `string` | n/a | yes |
| <a name="input_on_host_maintenance"></a> [on\_host\_maintenance](#input\_on\_host\_maintenance) | Instance availability Policy.<br/><br/>Note: Placement groups are not supported when on\_host\_maintenance is set to<br/>"MIGRATE" and will be deactivated regardless of the value of<br/>enable\_placement. To support enable\_placement, ensure on\_host\_maintenance is<br/>set to "TERMINATE". | `string` | `"TERMINATE"` | no |
| <a name="input_preemptible"></a> [preemptible](#input\_preemptible) | Should use preemptibles to burst. | `bool` | `false` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The default region for Cloud resources. | `string` | n/a | yes |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Service account e-mail address to attach to the compute instances. | `string` | `null` | no |
| <a name="input_service_account_scopes"></a> [service\_account\_scopes](#input\_service\_account\_scopes) | Scopes to attach to the compute instances. | `set(string)` | <pre>[<br/>  "https://www.googleapis.com/auth/cloud-platform"<br/>]</pre> | no |
| <a name="input_shielded_instance_config"></a> [shielded\_instance\_config](#input\_shielded\_instance\_config) | Shielded VM configuration for the instance. Note: not used unless<br/>enable\_shielded\_vm is 'true'.<br/>- enable\_integrity\_monitoring : Compare the most recent boot measurements to the<br/>  integrity policy baseline and return a pair of pass/fail results depending on<br/>  whether they match or not.<br/>- enable\_secure\_boot : Verify the digital signature of all boot components, and<br/>  halt the boot process if signature verification fails.<br/>- enable\_vtpm : Use a virtualized trusted platform module, which is a<br/>  specialized computer chip you can use to encrypt objects like keys and<br/>  certificates. | <pre>object({<br/>    enable_integrity_monitoring = bool<br/>    enable_secure_boot          = bool<br/>    enable_vtpm                 = bool<br/>  })</pre> | <pre>{<br/>  "enable_integrity_monitoring": true,<br/>  "enable_secure_boot": true,<br/>  "enable_vtpm": true<br/>}</pre> | no |
| <a name="input_slurm_bucket_path"></a> [slurm\_bucket\_path](#input\_slurm\_bucket\_path) | Path to the Slurm bucket. | `string` | n/a | yes |
| <a name="input_slurm_cluster_name"></a> [slurm\_cluster\_name](#input\_slurm\_cluster\_name) | Name of the Slurm cluster. | `string` | n/a | yes |
| <a name="input_spot_instance_config"></a> [spot\_instance\_config](#input\_spot\_instance\_config) | Configuration for spot VMs. | <pre>object({<br/>    termination_action = string<br/>  })</pre> | `null` | no |
| <a name="input_subnetwork_self_link"></a> [subnetwork\_self\_link](#input\_subnetwork\_self\_link) | Subnet to deploy to. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Network tag list. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instance_template_self_link"></a> [instance\_template\_self\_link](#output\_instance\_template\_self\_link) | The URI of the template. |
| <a name="output_node_name_prefix"></a> [node\_name\_prefix](#output\_node\_name\_prefix) | The prefix to be used for the node names. <br/><br/>Make sure that nodes are named `<node_name_prefix>-<any_suffix>`<br/>This temporary required for proper functioning of the nodes.<br/>While Slurm scheduler uses "features" to bind node and nodeset,<br/>the SlurmGCP relies on node names for this (to be switched to features as well). |
| <a name="output_nodeset_dyn"></a> [nodeset\_dyn](#output\_nodeset\_dyn) | Details of the nodeset. Typically used as input to `schedmd-slurm-gcp-v6-partition`. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
