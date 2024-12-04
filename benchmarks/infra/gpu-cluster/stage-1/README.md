# AI on GKE Benchmark Infrastructure

<!-- BEGIN TOC -->
- [AI on GKE Benchmark Infrastructure](#ai-on-gke-benchmark-infrastructure)
  - [Overview](#overview)
  - [Instructions](#instructions)
    - [Step 1: create and configure terraform.tfvars](#step-1-create-and-configure-terraformtfvars)
    - [Step 2: login to gcloud](#step-2-login-to-gcloud)
    - [Step 3: terraform initialize, plan and apply](#step-3-terraform-initialize-plan-and-apply)
    - [Step 4: verify](#step-4-verify)
  - [Variables](#variables)
  - [Outputs](#outputs)
<!-- END TOC -->

## Overview

This stage deploys a Standard GKE cluster optimized to run AI models on GPU accelerators. The cluster configuration follows the
Google best practices described in:
[GCP Fast Fabric modules](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric),
as well as the [GKE Jumpstart examples](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/blob/gke-blueprints/0-redis/blueprints/gke/jumpstart/jumpstart-0-infra/README.md).

In particular, stage-1 provisions:
- a private GKE cluster
- cluster nodepools

## Instructions

### Step 1: create and configure terraform.tfvars

Create a `terraform.tfvars` file. `./sample-tfvars/gpu-sample.tfvars` is provided as an example file. You can copy the file as a starting point. Note that you will have to change the existing `project_id`.

```bash
cp ./sample-tfvars/gpu-sample.tfvars terraform.tfvars
```

Fill out your `terraform.tfvars` with the desired project and cluster configuration, referring to the list of required and optional variables [here](#variables). Variables `cluster_name` and `project_id` are required.

### Step 2: login to gcloud

Run the following gcloud command for authorization:

```bash
gcloud auth application-default login
```

### Step 3: terraform initialize, plan and apply

Run the following terraform commands:

```bash
# initialize terraform
terraform init

# verify changes
terraform plan
# apply changes
terraform apply
```

### Step 4: verify

To verify that the cluster has been set up correctly, run
```
# Get credentials using fleet membership
gcloud container fleet memberships get-credentials <cluster-name>

# Run a kubectl command to verify
kubectl get nodes
```

<!-- BEGIN_TF_DOCS -->
## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of new or existing cluster. | `string` | n/a | yes |
| <a name="input_cluster_options"></a> [cluster\_options](#input\_cluster\_options) | Specific cluster configuration options | <pre>object({<br>    release_channel                       = optional(string, "REGULAR")<br>    enable_backup_agent                   = optional(bool, false)<br>    enable_gcs_fuse_csi_driver            = optional(bool, false)<br>    enable_gcp_filestore_csi_driver       = optional(bool, false)<br>    enable_gce_persistent_disk_csi_driver = optional(bool, false)<br>  })</pre> | `{}` | no |
| <a name="input_enable_private_endpoint"></a> [enable\_private\_endpoint](#input\_enable\_private\_endpoint) | When true, the cluster's private endpoint is used as the cluster endpoint and access through the public endpoint is disabled. | `bool` | `true` | no |
| <a name="input_filestore_storage"></a> [filestore\_storage](#input\_filestore\_storage) | Filestore storage instances. If GKE deployment is regional, tier should be set to ENTERPRISE | <pre>map(object({<br>    name        = string<br>    tier        = string<br>    capacity_gb = number<br>  }))</pre> | `{}` | no |
| <a name="input_gke_location"></a> [gke\_location](#input\_gke\_location) | Region or zone used for cluster. | `string` | `"us-central1-a"` | no |
| <a name="input_nodepools"></a> [nodepools](#input\_nodepools) | Nodepools for the cluster | <pre>map(object({<br>    machine_type   = optional(string, "n2-standard-2"),<br>    gke_version    = optional(string),<br>    max_node_count = optional(number, 10),<br>    min_node_count = optional(number, 1),<br><br>    guest_accelerator = optional(object({<br>      type  = optional(string),<br>      count = optional(number),<br>      gpu_driver = optional(object({<br>        version                    = optional(string, "LATEST"),<br>        partition_size             = optional(string),<br>        max_shared_clients_per_gpu = optional(number)<br>      }))<br>    }))<br><br>    ephemeral_ssd_block_config = optional(object({<br>      ephemeral_ssd_count = optional(number)<br>    }))<br><br>    local_nvme_ssd_block_config = optional(object({<br>      local_ssd_count = optional(number)<br>    }))<br>  }))</pre> | `{}` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix used for resource names. | `string` | `"ai-gke-0"` | no |
| <a name="input_private_cluster_config"></a> [private\_cluster\_config](#input\_private\_cluster\_config) | Private cluster configuration. Default of {} configures a private\_cluster with the values in below object. Set to null to make cluster public, which can be used for simple kubectl access when debugging or learning but should not be used in production.  May need to destroy & recreate to apply public cluster. | <pre>object({<br>    master_global_access = optional(bool, true)<br>  })</pre> | `{}` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id of existing or created project. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region used for network resources. | `string` | `"us-central1"` | no |
| <a name="input_vpc_create"></a> [vpc\_create](#input\_vpc\_create) | Project configuration for newly created VPC. Leave null to use existing VPC, or defaults when project creation is required. | <pre>object({<br>    name                     = optional(string)<br>    subnet_name              = optional(string)<br>    primary_range_nodes      = optional(string, "10.0.0.0/24")<br>    secondary_range_pods     = optional(string, "10.16.0.0/20")<br>    secondary_range_services = optional(string, "10.32.0.0/24")<br>    enable_cloud_nat         = optional(bool, false)<br>    proxy_only_subnet        = optional(string)<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_created_resources"></a> [created\_resources](#output\_created\_resources) | IDs of the resources created, if any. |
| <a name="output_fleet_host"></a> [fleet\_host](#output\_fleet\_host) | Fleet Connect Gateway host that can be used to configure the GKE provider. |
| <a name="output_get_credentials"></a> [get\_credentials](#output\_get\_credentials) | Run one of these commands to get cluster credentials. Credentials via fleet allow reaching private clusters without no direct connectivity. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | Project ID of where the GKE cluster is hosted |
<!-- END_TF_DOCS -->