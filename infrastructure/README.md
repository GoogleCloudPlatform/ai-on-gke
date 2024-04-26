# Setup Infra

The infrastructure module creates the GKE cluster and other related resources for the AI applications / workloads to be deployed on them. 

1) Update the ```platform.tfvars``` file with the required configuration. Kindly refer to ```tfvars_examples``` for sample configuration.

2) Run `terraform init` and `terraform apply --var-file=platform.tfvars`


## Prerequisites

For the GCP project where the infra resources are being created, the following prerequisites should  be met
- Billing is enabled
- GPU quotas in place

Following service APIs are enabled, 
- container.googleapis.com
- gkehub.googleapis.com
- servicenetworking.googleapis.com
- cloudresourcemanager.googleapis.com

if not already enabled, use the following command:
```
gcloud services enable container.googleapis.com gkehub.googleapis.com \
  servicenetworking.googleapis.com cloudresourcemanager.googleapis.com
```
## Network Connectivity

### Private GKE Cluster with internal endpoint
The default configuration in ```platform.tfvars``` creates a private GKE cluster with internal endpoints and adds the cluster to a project-scoped Anthos fleet.
For admin access to cluster, Anthos Connect Gateway is used. 

### Private GKE Cluster with external endpoint
Clusters with external endpoints can be accessed by configuing Autorized Networks. VPC network (10.100.0.0/16) is already configured for control plane authorized networks. 

## GPU Drivers
Lorum Ipsum

## Outputs
- cluster-name
- region
- project_id



## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.8.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.18.1 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cloud-nat"></a> [cloud-nat](#module\_cloud-nat) | terraform-google-modules/cloud-nat/google | 5.0.0 |
| <a name="module_custom-network"></a> [custom-network](#module\_custom-network) | terraform-google-modules/network/google | 8.0.0 |
| <a name="module_private-gke-autopilot-cluster"></a> [private-gke-autopilot-cluster](#module\_private-gke-autopilot-cluster) | ../modules/gke-autopilot-private-cluster | n/a |
| <a name="module_private-gke-standard-cluster"></a> [private-gke-standard-cluster](#module\_private-gke-standard-cluster) | ../modules/gke-standard-private-cluster | n/a |
| <a name="module_public-gke-autopilot-cluster"></a> [public-gke-autopilot-cluster](#module\_public-gke-autopilot-cluster) | ../modules/gke-autopilot-public-cluster | n/a |
| <a name="module_public-gke-standard-cluster"></a> [public-gke-standard-cluster](#module\_public-gke-standard-cluster) | ../modules/gke-standard-public-cluster | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_all_node_pools_labels"></a> [all\_node\_pools\_labels](#input\_all\_node\_pools\_labels) | n/a | `map(string)` | n/a | yes |
| <a name="input_all_node_pools_metadata"></a> [all\_node\_pools\_metadata](#input\_all\_node\_pools\_metadata) | n/a | `map(string)` | n/a | yes |
| <a name="input_all_node_pools_oauth_scopes"></a> [all\_node\_pools\_oauth\_scopes](#input\_all\_node\_pools\_oauth\_scopes) | n/a | `list(string)` | n/a | yes |
| <a name="input_all_node_pools_tags"></a> [all\_node\_pools\_tags](#input\_all\_node\_pools\_tags) | n/a | `list(string)` | n/a | yes |
| <a name="input_autopilot_cluster"></a> [autopilot\_cluster](#input\_autopilot\_cluster) | n/a | `bool` | n/a | yes |
| <a name="input_cluster_labels"></a> [cluster\_labels](#input\_cluster\_labels) | GKE cluster labels | `map` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | n/a | `string` | n/a | yes |
| <a name="input_cluster_region"></a> [cluster\_region](#input\_cluster\_region) | n/a | `string` | n/a | yes |
| <a name="input_cluster_regional"></a> [cluster\_regional](#input\_cluster\_regional) | n/a | `bool` | n/a | yes |
| <a name="input_cluster_zones"></a> [cluster\_zones](#input\_cluster\_zones) | n/a | `list(string)` | n/a | yes |
| <a name="input_cpu_pools"></a> [cpu\_pools](#input\_cpu\_pools) | n/a | `list(map(any))` | n/a | yes |
| <a name="input_create_cluster"></a> [create\_cluster](#input\_create\_cluster) | # GKE variables | `bool` | n/a | yes |
| <a name="input_create_network"></a> [create\_network](#input\_create\_network) | # network variables | `bool` | n/a | yes |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | n/a | `bool` | `false` | no |
| <a name="input_enable_gpu"></a> [enable\_gpu](#input\_enable\_gpu) | Set to true to create TPU node pool | `bool` | `true` | no |
| <a name="input_enable_tpu"></a> [enable\_tpu](#input\_enable\_tpu) | Set to true to create TPU node pool | `bool` | `false` | no |
| <a name="input_gcs_fuse_csi_driver"></a> [gcs\_fuse\_csi\_driver](#input\_gcs\_fuse\_csi\_driver) | n/a | `bool` | `false` | no |
| <a name="input_gpu_pools"></a> [gpu\_pools](#input\_gpu\_pools) | n/a | `list(map(any))` | n/a | yes |
| <a name="input_ip_range_pods"></a> [ip\_range\_pods](#input\_ip\_range\_pods) | n/a | `string` | n/a | yes |
| <a name="input_ip_range_services"></a> [ip\_range\_services](#input\_ip\_range\_services) | n/a | `string` | n/a | yes |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | n/a | `string` | `"latest"` | no |
| <a name="input_master_authorized_networks"></a> [master\_authorized\_networks](#input\_master\_authorized\_networks) | n/a | <pre>list(object({<br>    cidr_block   = string<br>    display_name = optional(string)<br>  }))</pre> | `[]` | no |
| <a name="input_monitoring_enable_managed_prometheus"></a> [monitoring\_enable\_managed\_prometheus](#input\_monitoring\_enable\_managed\_prometheus) | n/a | `bool` | `false` | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | n/a | `string` | n/a | yes |
| <a name="input_network_secondary_ranges"></a> [network\_secondary\_ranges](#input\_network\_secondary\_ranges) | n/a | `map(list(object({ range_name = string, ip_cidr_range = string })))` | n/a | yes |
| <a name="input_private_cluster"></a> [private\_cluster](#input\_private\_cluster) | n/a | `bool` | `true` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project id | `string` | `"umeshkumhar"` | no |
| <a name="input_region"></a> [region](#input\_region) | GCP project region or zone | `string` | `"us-central1"` | no |
| <a name="input_subnetwork_cidr"></a> [subnetwork\_cidr](#input\_subnetwork\_cidr) | n/a | `string` | n/a | yes |
| <a name="input_subnetwork_description"></a> [subnetwork\_description](#input\_subnetwork\_description) | n/a | `string` | n/a | yes |
| <a name="input_subnetwork_name"></a> [subnetwork\_name](#input\_subnetwork\_name) | n/a | `string` | n/a | yes |
| <a name="input_subnetwork_private_access"></a> [subnetwork\_private\_access](#input\_subnetwork\_private\_access) | n/a | `string` | n/a | yes |
| <a name="input_subnetwork_region"></a> [subnetwork\_region](#input\_subnetwork\_region) | n/a | `string` | n/a | yes |
| <a name="input_tpu_pools"></a> [tpu\_pools](#input\_tpu\_pools) | n/a | `list(map(any))` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_cluster_region"></a> [cluster\_region](#output\_cluster\_region) | n/a |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | n/a |
