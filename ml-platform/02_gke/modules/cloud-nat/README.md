<!--
Copyright 2024 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->
# Terraform Google Cloud NAT Module

This module handles opinionated Google Cloud Platform Cloud NAT creation and configuration.

## Compatibility
This module is meant for use with Terraform 0.13+ and tested using Terraform 1.0+. If you find incompatibilities using Terraform >=0.13, please open an issue.

## Usage

```hcl
module "cloud-nat" {
  source     = "terraform-google-modules/cloud-nat/google"
  version    = "~> 1.2"
  project_id = var.project_id
  region     = var.region
  router     = google_compute_router.router.name
}
```

Then perform the following commands on the root folder:

- `terraform init` to get the plugins
- `terraform plan` to see the infrastructure plan
- `terraform apply` to apply the infrastructure build
- `terraform destroy` to destroy the built infrastructure

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create\_router | Create router instead of using an existing one, uses 'router' variable for new resource name. | `bool` | `false` | no |
| enable\_dynamic\_port\_allocation | Enable Dynamic Port Allocation. If minPorts is set, minPortsPerVm must be set to a power of two greater than or equal to 32. | `bool` | `false` | no |
| enable\_endpoint\_independent\_mapping | Specifies if endpoint independent mapping is enabled. | `bool` | `null` | no |
| icmp\_idle\_timeout\_sec | Timeout (in seconds) for ICMP connections. Defaults to 30s if not set. Changing this forces a new NAT to be created. | `string` | `"30"` | no |
| log\_config\_enable | Indicates whether or not to export logs | `bool` | `false` | no |
| log\_config\_filter | Specifies the desired filtering of logs on this NAT. Valid values are: "ERRORS\_ONLY", "TRANSLATIONS\_ONLY", "ALL" | `string` | `"ALL"` | no |
| max\_ports\_per\_vm | Maximum number of ports allocated to a VM from this NAT. This field can only be set when enableDynamicPortAllocation is enabled.This will be ignored if enable\_dynamic\_port\_allocation is set to false. | `string` | `null` | no |
| min\_ports\_per\_vm | Minimum number of ports allocated to a VM from this NAT config. Defaults to 64 if not set. Changing this forces a new NAT to be created. | `string` | `"64"` | no |
| name | Defaults to 'cloud-nat-RANDOM\_SUFFIX'. Changing this forces a new NAT to be created. | `string` | `""` | no |
| nat\_ips | List of self\_links of external IPs. Changing this forces a new NAT to be created. Value of `nat_ip_allocate_option` is inferred based on nat\_ips. If present set to MANUAL\_ONLY, otherwise AUTO\_ONLY. | `list(string)` | `[]` | no |
| network | VPN name, only if router is not passed in and is created by the module. | `string` | `""` | no |
| project\_id | The project ID to deploy to | `string` | n/a | yes |
| region | The region to deploy to | `string` | n/a | yes |
| router | The name of the router in which this NAT will be configured. Changing this forces a new NAT to be created. | `string` | n/a | yes |
| router\_asn | Router ASN, only if router is not passed in and is created by the module. | `string` | `"64514"` | no |
| router\_keepalive\_interval | Router keepalive\_interval, only if router is not passed in and is created by the module. | `string` | `"20"` | no |
| source\_subnetwork\_ip\_ranges\_to\_nat | Defaults to ALL\_SUBNETWORKS\_ALL\_IP\_RANGES. How NAT should be configured per Subnetwork. Valid values include: ALL\_SUBNETWORKS\_ALL\_IP\_RANGES, ALL\_SUBNETWORKS\_ALL\_PRIMARY\_IP\_RANGES, LIST\_OF\_SUBNETWORKS. Changing this forces a new NAT to be created. | `string` | `"ALL_SUBNETWORKS_ALL_IP_RANGES"` | no |
| subnetworks | Specifies one or more subnetwork NAT configurations | <pre>list(object({<br>    name                     = string,<br>    source_ip_ranges_to_nat  = list(string)<br>    secondary_ip_range_names = list(string)<br>  }))</pre> | `[]` | no |
| tcp\_established\_idle\_timeout\_sec | Timeout (in seconds) for TCP established connections. Defaults to 1200s if not set. Changing this forces a new NAT to be created. | `string` | `"1200"` | no |
| tcp\_time\_wait\_timeout\_sec | Timeout (in seconds) for TCP connections that are in TIME\_WAIT state. Defaults to 120s if not set. | `string` | `"120"` | no |
| tcp\_transitory\_idle\_timeout\_sec | Timeout (in seconds) for TCP transitory connections. Defaults to 30s if not set. Changing this forces a new NAT to be created. | `string` | `"30"` | no |
| udp\_idle\_timeout\_sec | Timeout (in seconds) for UDP connections. Defaults to 30s if not set. Changing this forces a new NAT to be created. | `string` | `"30"` | no |

## Outputs

| Name | Description |
|------|-------------|
| name | Name of the Cloud NAT |
| nat\_ip\_allocate\_option | NAT IP allocation mode |
| region | Cloud NAT region |
| router\_name | Cloud NAT router name |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Requirements

Before this module can be used on a project, you must ensure that the following pre-requisites are fulfilled:

1. Terraform and kubectl are [installed](#software-dependencies) on the machine where Terraform is executed.
2. The Service Account you execute the module with has the right [permissions](#iam-roles).
3. The APIs are [active](#enable-apis) on the project you will launch the cluster in.
4. If you are using a Shared VPC, the APIs must also be activated on the Shared VPC host project and your service account needs the proper permissions there.

### Terraform plugins

- [Terraform](https://www.terraform.io/downloads.html) >= 0.13.0
- [terraform-provider-google](https://github.com/terraform-providers/terraform-provider-google) plugin v4.27.0

### Configure a Service Account

In order to execute this module you must have a Service Account with the
following project roles:

- [roles/compute.networkAdmin](https://cloud.google.com/nat/docs/using-nat#iam_permissions)

### Enable APIs

In order to operate with the Service Account you must activate the following APIs on the project where the Service Account was created:

- Compute Engine API - compute.googleapis.com

## Contributing

Refer to the [contribution guidelines](./CONTRIBUTING.md) for information on contributing to this module.
