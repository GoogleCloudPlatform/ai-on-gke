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

Create a `terraform.tfvars` file. `sample-terraform.tfvars` is provided as an example file. You can copy the file as a starting point. Note that you will have to change the existing `project_id`.

```bash
cp sample-terraform.tfvars terraform.tfvars
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

<!-- BEGIN TFDOC -->
## Variables

| name | description | type | required | default |
|---|---|:---:|:---:|:---:|
| [cluster_name](variables.tf#L22) | Name of new or existing cluster. | <code>string</code> | ✓ |  |
| [project_id](variables.tf#L17) | Project id of existing or created project. | <code>string</code> | ✓ |  |
| [cluster_options](variables.tf#L59) | Specific cluster configuration options | <code title="object&#40;&#123;&#10;  release_channel                       &#61; optional&#40;string, &#34;REGULAR&#34;&#41;&#10;  enable_backup_agent                   &#61; optional&#40;bool, false&#41;&#10;  enable_gcs_fuse_csi_driver            &#61; optional&#40;bool, false&#41;&#10;  enable_gcp_filestore_csi_driver       &#61; optional&#40;bool, false&#41;&#10;  enable_gce_persistent_disk_csi_driver &#61; optional&#40;bool, false&#41;&#10;&#125;&#41;">object&#40;&#123;&#8230;&#125;&#41;</code> |  | <code>&#123;&#125;</code> |
| [enable_private_endpoint](variables.tf#L39) | When true, the cluster's private endpoint is used as the cluster endpoint and access through the public endpoint is disabled. | <code>bool</code> |  | <code>true</code> |
| [filestore_storage](variables.tf#L96) | Filestore storage instances. If GKE deployment is regional, tier should be set to ENTERPRISE | <code title="map&#40;object&#40;&#123;&#10;  name        &#61; string&#10;  tier        &#61; string&#10;  capacity_gb &#61; number&#10;&#125;&#41;&#41;">map&#40;object&#40;&#123;&#8230;&#125;&#41;&#41;</code> |  | <code>&#123;&#125;</code> |
| [gke_location](variables.tf#L33) | Region or zone used for cluster. | <code>string</code> |  | <code>&#34;us-central1-a&#34;</code> |
| [nodepools](variables.tf#L71) | Nodepools for the cluster | <code title="map&#40;object&#40;&#123;&#10;  machine_type   &#61; optional&#40;string, &#34;n2-standard-2&#34;&#41;,&#10;  gke_version    &#61; optional&#40;string&#41;,&#10;  max_node_count &#61; optional&#40;number, 10&#41;,&#10;  min_node_count &#61; optional&#40;number, 1&#41;,&#10;&#10;&#10;  guest_accelerator &#61; optional&#40;object&#40;&#123;&#10;    type  &#61; optional&#40;string&#41;,&#10;    count &#61; optional&#40;number&#41;,&#10;    gpu_driver &#61; optional&#40;object&#40;&#123;&#10;      version                    &#61; optional&#40;string, &#34;LATEST&#34;&#41;,&#10;      partition_size             &#61; optional&#40;string&#41;,&#10;      max_shared_clients_per_gpu &#61; optional&#40;number&#41;&#10;    &#125;&#41;&#41;&#10;  &#125;&#41;&#41;&#10;&#10;&#10;  local_nvme_ssd_block_config &#61; optional&#40;object&#40;&#123;&#10;    local_ssd_count &#61; optional&#40;number&#41;&#10;  &#125;&#41;&#41;&#10;&#125;&#41;&#41;">map&#40;object&#40;&#123;&#8230;&#125;&#41;&#41;</code> |  | <code>&#123;&#125;</code> |
| [region](variables.tf#L27) | Region used for network resources. | <code>string</code> |  | <code>&#34;us-central1&#34;</code> |
| [vpc_create](variables.tf#L45) | Project configuration for newly created VPC. Leave null to use existing VPC, or defaults when project creation is required. | <code title="object&#40;&#123;&#10;  name                     &#61; optional&#40;string&#41;&#10;  subnet_name              &#61; optional&#40;string&#41;&#10;  primary_range_nodes      &#61; optional&#40;string, &#34;10.0.0.0&#47;24&#34;&#41;&#10;  secondary_range_pods     &#61; optional&#40;string, &#34;10.16.0.0&#47;20&#34;&#41;&#10;  secondary_range_services &#61; optional&#40;string, &#34;10.32.0.0&#47;24&#34;&#41;&#10;  enable_cloud_nat         &#61; optional&#40;bool, false&#41;&#10;  proxy_only_subnet        &#61; optional&#40;string&#41;&#10;&#125;&#41;">object&#40;&#123;&#8230;&#125;&#41;</code> |  | <code>null</code> |

## Outputs

| name | description | sensitive |
|---|---|:---:|
| [created_resources](outputs.tf#L17) | IDs of the resources created, if any. |  |
| [fleet_host](outputs.tf#L27) | Fleet Connect Gateway host that can be used to configure the GKE provider. |  |
| [get_credentials](outputs.tf#L32) | Run one of these commands to get cluster credentials. Credentials via fleet allow reaching private clusters without no direct connectivity. |  |
| [project_id](outputs.tf#L22) | Project ID of where the GKE cluster is hosted |  |
<!-- END TFDOC -->
