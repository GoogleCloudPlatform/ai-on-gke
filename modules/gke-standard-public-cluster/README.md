# GKE Public Standard Cluster

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_gke"></a> [gke](#module\_gke) | terraform-google-modules/kubernetes-engine/google | 28.0.0 |

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
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | n/a | `string` | n/a | yes |
| <a name="input_cluster_region"></a> [cluster\_region](#input\_cluster\_region) | n/a | `string` | n/a | yes |
| <a name="input_cluster_regional"></a> [cluster\_regional](#input\_cluster\_regional) | # GKE variables | `bool` | n/a | yes |
| <a name="input_cluster_zones"></a> [cluster\_zones](#input\_cluster\_zones) | n/a | `list(string)` | n/a | yes |
| <a name="input_cpu_pools"></a> [cpu\_pools](#input\_cpu\_pools) | n/a | `list(map(any))` | n/a | yes |
| <a name="input_enable_gpu"></a> [enable\_gpu](#input\_enable\_gpu) | Set to true to create TPU node pool | `bool` | `true` | no |
| <a name="input_enable_tpu"></a> [enable\_tpu](#input\_enable\_tpu) | Set to true to create TPU node pool | `bool` | `false` | no |
| <a name="input_gpu_pools"></a> [gpu\_pools](#input\_gpu\_pools) | n/a | `list(map(any))` | n/a | yes |
| <a name="input_ip_range_pods"></a> [ip\_range\_pods](#input\_ip\_range\_pods) | n/a | `string` | n/a | yes |
| <a name="input_ip_range_services"></a> [ip\_range\_services](#input\_ip\_range\_services) | n/a | `string` | n/a | yes |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | n/a | `string` | n/a | yes |
| <a name="input_master_authorized_networks"></a> [master\_authorized\_networks](#input\_master\_authorized\_networks) | n/a | <pre>list(object({<br>    cidr_block   = string<br>    display_name = string<br>  }))</pre> | `[]` | no |
| <a name="input_monitoring_enable_managed_prometheus"></a> [monitoring\_enable\_managed\_prometheus](#input\_monitoring\_enable\_managed\_prometheus) | n/a | `bool` | `false` | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | # network variables | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project id | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | GCP project region or zone | `string` | `"us-central1"` | no |
| <a name="input_release_channel"></a> [release\_channel](#input\_release\_channel) | n/a | `string` | n/a | yes |
| <a name="input_subnetwork_name"></a> [subnetwork\_name](#input\_subnetwork\_name) | n/a | `string` | n/a | yes |
| <a name="input_tpu_pools"></a> [tpu\_pools](#input\_tpu\_pools) | n/a | `list(map(any))` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster"></a> [cluster](#output\_cluster) | n/a |
