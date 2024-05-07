# AI on GKE Benchmark Framework Infrastructure

This module allows to deploy a secure cluster that meets Google's best practices, optimized to running AI models.

<!-- BEGIN TOC -->
- [Design Decisions](#design-decisions)
- [Examples](#examples)
  - [New cluster and VPC, implied cluster VPC, GCS Fuse enabled, CPU Nodepool](#new-cluster-and-vpc-implied-cluster-vpc-gcs-fuse-enabled-cpu-nodepool)
  - [New cluster and VPC, implied cluster VPC, GCS Fuse enabled, GPU Nodepool](#new-cluster-and-vpc-implied-cluster-vpc-gcs-fuse-enabled-gpu-nodepool)
- [Variables](#variables)
- [Outputs](#outputs)
<!-- END TOC -->

## Design Decisions

The main purpose of this module is to allow to use GKE features to deploy a secure GKE cluster optimized to running and benchmarking AI models. As per decision the cluster will follow the
Google best practices, basing on:
[GCP Fast Fabric modules](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric),
esp the [GKE Jumpstart examples](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/blob/gke-blueprints/0-redis/blueprints/gke/jumpstart/jumpstart-0-infra/README.md).

## Examples

### New cluster and VPC, implied cluster VPC, GCS Fuse enabled, CPU Nodepool

```hcl
module "benchmark-0-infra" {
  source       = "../ai-on-gke-benchmark-0-infra/"
  project_id   = "sample-project-id"
  cluster_name = "test-00"

  cluster_create = {
    options = {
      enable_gcs_fuse_csi_driver            = true
      enable_gcp_filestore_csi_driver       = true
      enable_gce_persistent_disk_csi_driver = true
    }
  }
  vpc_create = {}

  nodepools = {
    "nodepool-cpu" : {
      machine_type = "n2-standard-2"
    }
  }
}
```

### New cluster and VPC, implied cluster VPC, GCS Fuse enabled, GPU Nodepool

```hcl
module "benchmark-0-infra" {
  source       = "../ai-on-gke-benchmark-0-infra/"
  project_id   = "sample-project-id"
  cluster_name = "test-00"

  cluster_create = {
    options = {
      enable_gcs_fuse_csi_driver            = true
      enable_gcp_filestore_csi_driver       = true
      enable_gce_persistent_disk_csi_driver = true
    }
  }
  vpc_create = {}

  nodepools = {
    "nodepool-gpu" : {
      machine_type = "nvidia-tesla-t4",
      guest_accelerator = {
        type  = "nvidia-tesla-k80",
        count = 1,
      }
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
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

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cluster-autopilot"></a> [cluster-autopilot](#module\_cluster-autopilot) | git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/gke-cluster-autopilot | v30.0.0&depth=1 |
| <a name="module_cluster-nodepool"></a> [cluster-nodepool](#module\_cluster-nodepool) | git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/gke-nodepool | v30.0.0&depth=1 |
| <a name="module_cluster-service-account"></a> [cluster-service-account](#module\_cluster-service-account) | git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/iam-service-account | v30.0.0&depth=1 |
| <a name="module_cluster-standard"></a> [cluster-standard](#module\_cluster-standard) | git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/gke-cluster-standard | v30.0.0&depth=1 |
| <a name="module_fleet"></a> [fleet](#module\_fleet) | git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/gke-hub | v30.0.0&depth=1 |
| <a name="module_fleet-project"></a> [fleet-project](#module\_fleet-project) | git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/project | v30.0.0&depth=1 |
| <a name="module_nat"></a> [nat](#module\_nat) | git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/net-cloudnat | v30.0.0&depth=1 |
| <a name="module_project"></a> [project](#module\_project) | git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/project | v30.0.0&depth=1 |
| <a name="module_registry"></a> [registry](#module\_registry) | git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/artifact-registry | v30.0.0&depth=1 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/net-vpc | n/a |

## Resources

| Name | Type |
|------|------|
| [google_filestore_instance.instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/filestore_instance) | resource |
| [google_container_cluster.cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/container_cluster) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_create"></a> [cluster\_create](#input\_cluster\_create) | Cluster configuration for newly created cluster. Set to null to use existing cluster, or create using defaults in new project. | <pre>object({<br>    labels = optional(map(string))<br>    master_authorized_ranges = optional(map(string), {<br>      rfc-1918-10-8 = "10.0.0.0/8"<br>    })<br>    master_ipv4_cidr_block = optional(string, "172.16.255.0/28")<br>    vpc = optional(object({<br>      id        = string<br>      subnet_id = string<br>      secondary_range_names = optional(object({<br>        pods     = optional(string, "pods")<br>        services = optional(string, "services")<br>      }), {})<br>    }))<br>    version = optional(string)<br>    options = optional(object({<br>      release_channel                       = optional(string, "REGULAR")<br>      enable_backup_agent                   = optional(bool, false)<br>      dns_cache                             = optional(bool, true)<br>      enable_gcs_fuse_csi_driver            = optional(bool, false)<br>      enable_gcp_filestore_csi_driver       = optional(bool, false)<br>      enable_gce_persistent_disk_csi_driver = optional(bool, false)<br>    }), {})<br>  })</pre> | `null` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of new or existing cluster. | `string` | n/a | yes |
| <a name="input_enable_private_endpoint"></a> [enable\_private\_endpoint](#input\_enable\_private\_endpoint) | When true, the cluster's private endpoint is used as the cluster endpoint and access through the public endpoint is disabled. | `bool` | `true` | no |
| <a name="input_filestore_storage"></a> [filestore\_storage](#input\_filestore\_storage) | Filestore storage instances. If GKE deployment is regional, tier should be set to ENTERPRISE | <pre>map(object({<br>    name        = string<br>    tier        = string<br>    capacity_gb = number<br>  }))</pre> | `{}` | no |
| <a name="input_fleet_project_id"></a> [fleet\_project\_id](#input\_fleet\_project\_id) | GKE Fleet project id. If null cluster project will also be used for fleet. | `string` | `null` | no |
| <a name="input_gke_autopilot"></a> [gke\_autopilot](#input\_gke\_autopilot) | Create GKE Autopiot cluster | `bool` | `false` | no |
| <a name="input_gke_location"></a> [gke\_location](#input\_gke\_location) | Region or zone used for cluster. | `string` | `"us-central1-a"` | no |
| <a name="input_node_locations"></a> [node\_locations](#input\_node\_locations) | Zones in which the GKE Autopilot cluster's nodes are located. | `list(string)` | `[]` | no |
| <a name="input_nodepools"></a> [nodepools](#input\_nodepools) | Nodepools for the GKE Standard cluster | <pre>map(object({<br>    machine_type   = optional(string, "n2-standard-2"),<br>    gke_version    = optional(string),<br>    max_node_count = optional(number, 10),<br>    min_node_count = optional(number, 1),<br><br>    guest_accelerator = optional(object({<br>      type  = optional(string),<br>      count = optional(number),<br>      gpu_driver = optional(object({<br>        version                    = string<br>        partition_size             = optional(string)<br>        max_shared_clients_per_gpu = optional(number)<br>      }))<br>    }))<br><br>    ephemeral_ssd_block_config = optional(object({<br>      ephemeral_ssd_count = optional(number)<br>    }))<br><br>    local_nvme_ssd_block_config = optional(object({<br>      local_ssd_count = optional(number)<br>    }))<br>  }))</pre> | `{}` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix used for resource names. | `string` | `"ai-gke-0"` | no |
| <a name="input_private_cluster_config"></a> [private\_cluster\_config](#input\_private\_cluster\_config) | Private cluster configuration. Default of {} configures a private\_cluster with the values in below object. Set to null to make cluster public, which can be used for simple kubectl access when debugging or learning but should not be used in production. | <pre>object({<br>    # Is overriden by above variable enable_private_endpoint<br>    enable_private_endpoint = optional(bool, true)<br>    master_global_access    = optional(bool, true)<br>  })</pre> | `{}` | no |
| <a name="input_project_create"></a> [project\_create](#input\_project\_create) | Project configuration for newly created project. Leave null to use existing project. Project creation forces VPC and cluster creation. | <pre>object({<br>    billing_account = string<br>    parent          = optional(string)<br>    shared_vpc_host = optional(string)<br>  })</pre> | `null` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id of existing or created project. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region used for network resources. | `string` | `"us-central1"` | no |
| <a name="input_registry_create"></a> [registry\_create](#input\_registry\_create) | Create remote Docker Artifact Registry. | `bool` | `true` | no |
| <a name="input_vpc_create"></a> [vpc\_create](#input\_vpc\_create) | Project configuration for newly created VPC. Leave null to use existing VPC, or defaults when project creation is required. | <pre>object({<br>    name                     = optional(string)<br>    subnet_name              = optional(string)<br>    primary_range_nodes      = optional(string, "10.0.0.0/24")<br>    secondary_range_pods     = optional(string, "10.16.0.0/20")<br>    secondary_range_services = optional(string, "10.32.0.0/24")<br>    enable_cloud_nat         = optional(bool, false)<br>    proxy_only_subnet        = optional(string)<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_created_resources"></a> [created\_resources](#output\_created\_resources) | IDs of the resources created, if any. |
| <a name="output_fleet_host"></a> [fleet\_host](#output\_fleet\_host) | Fleet Connect Gateway host that can be used to configure the GKE provider. |
| <a name="output_get_credentials"></a> [get\_credentials](#output\_get\_credentials) | Run one of these commands to get cluster credentials. Credentials via fleet allow reaching private clusters without no direct connectivity. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | Project ID of where the GKE cluster is hosted |
<!-- END_TF_DOCS -->