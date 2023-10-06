# GKE Standard Cluster

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 4.8 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.8.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | 2.0.1 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.18.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 4.83.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_gke"></a> [gke](#module\_gke) | terraform-google-modules/kubernetes-engine/google | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-google-modules/network/google//modules/subnets | n/a |

## Resources

| Name | Type |
|------|------|
| [google_compute_network.custom-network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_all_node_pools_labels"></a> [all\_node\_pools\_labels](#input\_all\_node\_pools\_labels) | n/a | `map(string)` | n/a | yes |
| <a name="input_all_node_pools_metadata"></a> [all\_node\_pools\_metadata](#input\_all\_node\_pools\_metadata) | n/a | `map(string)` | n/a | yes |
| <a name="input_all_node_pools_oauth_scopes"></a> [all\_node\_pools\_oauth\_scopes](#input\_all\_node\_pools\_oauth\_scopes) | n/a | `list(string)` | n/a | yes |
| <a name="input_all_node_pools_tags"></a> [all\_node\_pools\_tags](#input\_all\_node\_pools\_tags) | n/a | `list(string)` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | # GKE variables | `string` | n/a | yes |
| <a name="input_cluster_region"></a> [cluster\_region](#input\_cluster\_region) | n/a | `string` | n/a | yes |
| <a name="input_cluster_zones"></a> [cluster\_zones](#input\_cluster\_zones) | n/a | `list(string)` | n/a | yes |
| <a name="input_create_network"></a> [create\_network](#input\_create\_network) | # network variables | `bool` | n/a | yes |
| <a name="input_enable_autopilot"></a> [enable\_autopilot](#input\_enable\_autopilot) | Set to true to enable GKE Autopilot clusters | `bool` | `false` | no |
| <a name="input_enable_gpu"></a> [enable\_gpu](#input\_enable\_gpu) | Set to true to create TPU node pool | `bool` | `true` | no |
| <a name="input_enable_tpu"></a> [enable\_tpu](#input\_enable\_tpu) | Set to true to create TPU node pool | `bool` | `false` | no |
| <a name="input_ip_range_pods"></a> [ip\_range\_pods](#input\_ip\_range\_pods) | n/a | `string` | n/a | yes |
| <a name="input_ip_range_services"></a> [ip\_range\_services](#input\_ip\_range\_services) | n/a | `string` | n/a | yes |
| <a name="input_monitoring_enable_managed_prometheus"></a> [monitoring\_enable\_managed\_prometheus](#input\_monitoring\_enable\_managed\_prometheus) | n/a | `bool` | `false` | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | n/a | `string` | n/a | yes |
| <a name="input_network_secondary_ranges"></a> [network\_secondary\_ranges](#input\_network\_secondary\_ranges) | n/a | `map()` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project id | `string` | `"umeshkumhar"` | no |
| <a name="input_region"></a> [region](#input\_region) | GCP project region or zone | `string` | `"us-central1"` | no |
| <a name="input_subnetwork_cidr"></a> [subnetwork\_cidr](#input\_subnetwork\_cidr) | n/a | `string` | n/a | yes |
| <a name="input_subnetwork_description"></a> [subnetwork\_description](#input\_subnetwork\_description) | n/a | `string` | n/a | yes |
| <a name="input_subnetwork_name"></a> [subnetwork\_name](#input\_subnetwork\_name) | n/a | `string` | n/a | yes |
| <a name="input_subnetwork_private_access"></a> [subnetwork\_private\_access](#input\_subnetwork\_private\_access) | n/a | `string` | n/a | yes |
| <a name="input_subnetwork_region"></a> [subnetwork\_region](#input\_subnetwork\_region) | n/a | `string` | n/a | yes |

## Outputs

No outputs.