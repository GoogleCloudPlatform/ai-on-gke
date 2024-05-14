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
<!-- BEGIN TFDOC -->
## Variables

| name | description | type | required | default |
|---|---|:---:|:---:|:---:|
| [cluster_name](variables.tf#L81) | Name of new or existing cluster. | <code>string</code> | ✓ |  |
| [project_id](variables.tf#L101) | Project id of existing or created project. | <code>string</code> | ✓ |  |
| [cluster_create](variables.tf#L17) | Cluster configuration for newly created cluster. Set to null to use existing cluster, or create using defaults in new project. | <code title="object&#40;&#123;&#10;  labels &#61; optional&#40;map&#40;string&#41;&#41;&#10;  master_authorized_ranges &#61; optional&#40;map&#40;string&#41;, &#123;&#10;    rfc-1918-10-8 &#61; &#34;10.0.0.0&#47;8&#34;&#10;  &#125;&#41;&#10;  master_ipv4_cidr_block &#61; optional&#40;string, &#34;172.16.255.0&#47;28&#34;&#41;&#10;  vpc &#61; optional&#40;object&#40;&#123;&#10;    id        &#61; string&#10;    subnet_id &#61; string&#10;    secondary_range_names &#61; optional&#40;object&#40;&#123;&#10;      pods     &#61; optional&#40;string, &#34;pods&#34;&#41;&#10;      services &#61; optional&#40;string, &#34;services&#34;&#41;&#10;    &#125;&#41;, &#123;&#125;&#41;&#10;  &#125;&#41;&#41;&#10;  version &#61; optional&#40;string&#41;&#10;  options &#61; optional&#40;object&#40;&#123;&#10;    release_channel                       &#61; optional&#40;string, &#34;REGULAR&#34;&#41;&#10;    enable_backup_agent                   &#61; optional&#40;bool, false&#41;&#10;    enable_gcs_fuse_csi_driver            &#61; optional&#40;bool, false&#41;&#10;    enable_gcp_filestore_csi_driver       &#61; optional&#40;bool, false&#41;&#10;    enable_gce_persistent_disk_csi_driver &#61; optional&#40;bool, false&#41;&#10;  &#125;&#41;, &#123;&#125;&#41;&#10;&#125;&#41;">object&#40;&#123;&#8230;&#125;&#41;</code> |  | <code>null</code> |
| [enable_private_endpoint](variables.tf#L75) | When true, the cluster's private endpoint is used as the cluster endpoint and access through the public endpoint is disabled. | <code>bool</code> |  | <code>true</code> |
| [filestore_storage](variables.tf#L143) | Filestore storage instances. If GKE deployment is regional, tier should be set to ENTERPRISE | <code title="map&#40;object&#40;&#123;&#10;  name        &#61; string&#10;  tier        &#61; string&#10;  capacity_gb &#61; number&#10;&#125;&#41;&#41;">map&#40;object&#40;&#123;&#8230;&#125;&#41;&#41;</code> |  | <code>&#123;&#125;</code> |
| [fleet_project_id](variables.tf#L88) | GKE Fleet project id. If null cluster project will also be used for fleet. | <code>string</code> |  | <code>null</code> |
| [gke_location](variables.tf#L112) | Region or zone used for cluster. | <code>string</code> |  | <code>&#34;us-central1-a&#34;</code> |
| [nodepools](variables.tf#L118) | Nodepools for the cluster | <code title="map&#40;object&#40;&#123;&#10;  machine_type   &#61; optional&#40;string, &#34;n2-standard-2&#34;&#41;,&#10;  gke_version    &#61; optional&#40;string&#41;,&#10;  max_node_count &#61; optional&#40;number, 10&#41;,&#10;  min_node_count &#61; optional&#40;number, 1&#41;,&#10;&#10;&#10;  guest_accelerator &#61; optional&#40;object&#40;&#123;&#10;    type  &#61; optional&#40;string&#41;,&#10;    count &#61; optional&#40;number&#41;,&#10;    gpu_driver &#61; optional&#40;object&#40;&#123;&#10;      version                    &#61; string&#10;      partition_size             &#61; optional&#40;string&#41;&#10;      max_shared_clients_per_gpu &#61; optional&#40;number&#41;&#10;    &#125;&#41;&#41;&#10;  &#125;&#41;&#41;&#10;&#10;&#10;  local_nvme_ssd_block_config &#61; optional&#40;object&#40;&#123;&#10;    local_ssd_count &#61; optional&#40;number&#41;&#10;  &#125;&#41;&#41;&#10;&#125;&#41;&#41;">map&#40;object&#40;&#123;&#8230;&#125;&#41;&#41;</code> |  | <code>&#123;&#125;</code> |
| [prefix](variables.tf#L94) | Prefix used for resource names. | <code>string</code> |  | <code>&#34;ai-gke-0&#34;</code> |
| [project_create](variables.tf#L45) | Project configuration for newly created project. Leave null to use existing project. Project creation forces VPC and cluster creation. | <code title="object&#40;&#123;&#10;  billing_account &#61; string&#10;  parent          &#61; optional&#40;string&#41;&#10;  shared_vpc_host &#61; optional&#40;string&#41;&#10;&#125;&#41;">object&#40;&#123;&#8230;&#125;&#41;</code> |  | <code>null</code> |
| [region](variables.tf#L106) | Region used for network resources. | <code>string</code> |  | <code>&#34;us-central1&#34;</code> |
| [registry_create](variables.tf#L55) | Create remote Docker Artifact Registry. | <code>bool</code> |  | <code>true</code> |
| [vpc_create](variables.tf#L61) | Project configuration for newly created VPC. Leave null to use existing VPC, or defaults when project creation is required. | <code title="object&#40;&#123;&#10;  name                     &#61; optional&#40;string&#41;&#10;  subnet_name              &#61; optional&#40;string&#41;&#10;  primary_range_nodes      &#61; optional&#40;string, &#34;10.0.0.0&#47;24&#34;&#41;&#10;  secondary_range_pods     &#61; optional&#40;string, &#34;10.16.0.0&#47;20&#34;&#41;&#10;  secondary_range_services &#61; optional&#40;string, &#34;10.32.0.0&#47;24&#34;&#41;&#10;  enable_cloud_nat         &#61; optional&#40;bool, false&#41;&#10;  proxy_only_subnet        &#61; optional&#40;string&#41;&#10;&#125;&#41;">object&#40;&#123;&#8230;&#125;&#41;</code> |  | <code>null</code> |

## Outputs

| name | description | sensitive |
|---|---|:---:|
| [created_resources](outputs.tf#L17) | IDs of the resources created, if any. |  |
| [fleet_host](outputs.tf#L49) | Fleet Connect Gateway host that can be used to configure the GKE provider. |  |
| [get_credentials](outputs.tf#L58) | Run one of these commands to get cluster credentials. Credentials via fleet allow reaching private clusters without no direct connectivity. |  |
| [project_id](outputs.tf#L44) | Project ID of where the GKE cluster is hosted |  |
<!-- END TFDOC -->
