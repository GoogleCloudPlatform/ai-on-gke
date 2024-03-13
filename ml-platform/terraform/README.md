## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_github"></a> [github](#requirement\_github) | 6.0.1 |
| <a name="requirement_google"></a> [google](#requirement\_google) | 5.19.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | 5.19.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | 3.2.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_github"></a> [github](#provider\_github) | 6.0.1 |
| <a name="provider_google"></a> [google](#provider\_google) | 5.19.0 |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | 5.19.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cloud-nat"></a> [cloud-nat](#module\_cloud-nat) | ./modules/cloud-nat | n/a |
| <a name="module_create-vpc"></a> [create-vpc](#module\_create-vpc) | ./modules/network | n/a |
| <a name="module_gcp-project"></a> [gcp-project](#module\_gcp-project) | ./modules/projects | n/a |
| <a name="module_gke"></a> [gke](#module\_gke) | ./modules/cluster | n/a |
| <a name="module_node_pool-ondemand"></a> [node\_pool-ondemand](#module\_node\_pool-ondemand) | ./modules/node-pools | n/a |
| <a name="module_node_pool-reserved"></a> [node\_pool-reserved](#module\_node\_pool-reserved) | ./modules/node-pools | n/a |
| <a name="module_node_pool-spot"></a> [node\_pool-spot](#module\_node\_pool-spot) | ./modules/node-pools | n/a |
| <a name="module_reservation"></a> [reservation](#module\_reservation) | ./modules/vm-reservations | n/a |

## Resources

| Name | Type |
|------|------|
| [github_branch.branch](https://registry.terraform.io/providers/integrations/github/6.0.1/docs/resources/branch) | resource |
| [github_branch_default.default_branch](https://registry.terraform.io/providers/integrations/github/6.0.1/docs/resources/branch_default) | resource |
| [github_branch_protection_v3.branch_protection](https://registry.terraform.io/providers/integrations/github/6.0.1/docs/resources/branch_protection_v3) | resource |
| [github_repository.acm_repo](https://registry.terraform.io/providers/integrations/github/6.0.1/docs/resources/repository) | resource |
| [google-beta_google_gke_hub_feature.configmanagement_acm_feature](https://registry.terraform.io/providers/hashicorp/google-beta/5.19.0/docs/resources/google_gke_hub_feature) | resource |
| [google-beta_google_gke_hub_feature_membership.feature_member](https://registry.terraform.io/providers/hashicorp/google-beta/5.19.0/docs/resources/google_gke_hub_feature_membership) | resource |
| [google-beta_google_gke_hub_membership.membership](https://registry.terraform.io/providers/hashicorp/google-beta/5.19.0/docs/resources/google_gke_hub_membership) | resource |
| [google_project_service.project_services-an](https://registry.terraform.io/providers/hashicorp/google/5.19.0/docs/resources/project_service) | resource |
| [google_project_service.project_services-anc](https://registry.terraform.io/providers/hashicorp/google/5.19.0/docs/resources/project_service) | resource |
| [google_project_service.project_services-com](https://registry.terraform.io/providers/hashicorp/google/5.19.0/docs/resources/project_service) | resource |
| [google_project_service.project_services-con](https://registry.terraform.io/providers/hashicorp/google/5.19.0/docs/resources/project_service) | resource |
| [google_project_service.project_services-cr](https://registry.terraform.io/providers/hashicorp/google/5.19.0/docs/resources/project_service) | resource |
| [google_project_service.project_services-gate](https://registry.terraform.io/providers/hashicorp/google/5.19.0/docs/resources/project_service) | resource |
| [google_project_service.project_services-gkecon](https://registry.terraform.io/providers/hashicorp/google/5.19.0/docs/resources/project_service) | resource |
| [google_project_service.project_services-gkeh](https://registry.terraform.io/providers/hashicorp/google/5.19.0/docs/resources/project_service) | resource |
| [google_project_service.project_services-iam](https://registry.terraform.io/providers/hashicorp/google/5.19.0/docs/resources/project_service) | resource |
| [null_resource.create_git_cred_cms](https://registry.terraform.io/providers/hashicorp/null/3.2.2/docs/resources/resource) | resource |
| [null_resource.create_git_cred_ns](https://registry.terraform.io/providers/hashicorp/null/3.2.2/docs/resources/resource) | resource |
| [null_resource.create_namespace](https://registry.terraform.io/providers/hashicorp/null/3.2.2/docs/resources/resource) | resource |
| [null_resource.install_kuberay_operator](https://registry.terraform.io/providers/hashicorp/null/3.2.2/docs/resources/resource) | resource |
| [null_resource.install_ray_cluster](https://registry.terraform.io/providers/hashicorp/null/3.2.2/docs/resources/resource) | resource |
| [null_resource.manage_ray_ns](https://registry.terraform.io/providers/hashicorp/null/3.2.2/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_billing_account"></a> [billing\_account](#input\_billing\_account) | GCP billing account | `string` | `null` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the GKE cluster | `string` | `"gke-ml"` | no |
| <a name="input_configsync_repo_name"></a> [configsync\_repo\_name](#input\_configsync\_repo\_name) | Name of the GitHub repo that will be synced to the cluster with Config sync. | `string` | `"config-sync-repo"` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Setup a namespace to demo. | `number` | `1` | no |
| <a name="input_create_projects"></a> [create\_projects](#input\_create\_projects) | Flag to create GCP projects | `number` | `0` | no |
| <a name="input_env"></a> [env](#input\_env) | List of environments | `set(string)` | <pre>[<br>  "dev"<br>]</pre> | no |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | Folder Id where the GCP projects will be created | `string` | `null` | no |
| <a name="input_github_email"></a> [github\_email](#input\_github\_email) | GitHub user email. | `string` | n/a | yes |
| <a name="input_github_org"></a> [github\_org](#input\_github\_org) | GitHub org. | `string` | n/a | yes |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | GitHub token. It is a token with write permissions as it will create a repo in the GitHub org. | `string` | n/a | yes |
| <a name="input_github_user"></a> [github\_user](#input\_github\_user) | GitHub user name. | `string` | n/a | yes |
| <a name="input_install_kuberay"></a> [install\_kuberay](#input\_install\_kuberay) | Flag to install kuberay operator. | `number` | `1` | no |
| <a name="input_install_ray_in_ns"></a> [install\_ray\_in\_ns](#input\_install\_ray\_in\_ns) | Flag to install ray cluster in the namespace created with the demo. | `number` | `1` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Name of the namespace to demo. | `string` | `"ml-team"` | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | VPC network where GKE cluster will be created | `string` | `"ml-vpc"` | no |
| <a name="input_ondemand_taints"></a> [ondemand\_taints](#input\_ondemand\_taints) | Taints to be applied to the on-demand node pool. | <pre>list(object({<br>    key    = string<br>    value  = any<br>    effect = string<br>  }))</pre> | <pre>[<br>  {<br>    "effect": "NO_SCHEDULE",<br>    "key": "ondemand",<br>    "value": true<br>  }<br>]</pre> | no |
| <a name="input_org_id"></a> [org\_id](#input\_org\_id) | The GCP orig id | `string` | `null` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project where the resources will be created. It is a map with environments as keys and project\_ids s values | `map` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | GCP project name | `string` | `null` | no |
| <a name="input_reserved_taints"></a> [reserved\_taints](#input\_reserved\_taints) | Taints to be applied to the reserved node pool. | <pre>list(object({<br>    key    = string<br>    value  = any<br>    effect = string<br>  }))</pre> | <pre>[<br>  {<br>    "effect": "NO_SCHEDULE",<br>    "key": "reserved",<br>    "value": true<br>  }<br>]</pre> | no |
| <a name="input_routing_mode"></a> [routing\_mode](#input\_routing\_mode) | VPC routing mode. | `string` | `"GLOBAL"` | no |
| <a name="input_secret_for_rootsync"></a> [secret\_for\_rootsync](#input\_secret\_for\_rootsync) | Create git-cred in config-management-system namespace. | `number` | `1` | no |
| <a name="input_spot_taints"></a> [spot\_taints](#input\_spot\_taints) | Taints to be applied to the spot node pool. | <pre>list(object({<br>    key    = string<br>    value  = any<br>    effect = string<br>  }))</pre> | <pre>[<br>  {<br>    "effect": "NO_SCHEDULE",<br>    "key": "spot",<br>    "value": true<br>  }<br>]</pre> | no |
| <a name="input_subnet_01_description"></a> [subnet\_01\_description](#input\_subnet\_01\_description) | Description of the first subnet. | `string` | `"subnet 01"` | no |
| <a name="input_subnet_01_ip"></a> [subnet\_01\_ip](#input\_subnet\_01\_ip) | CIDR of the first subnet. | `string` | `"10.40.0.0/22"` | no |
| <a name="input_subnet_01_name"></a> [subnet\_01\_name](#input\_subnet\_01\_name) | Name of the first subnet in the VPC network. | `string` | `"ml-vpc-subnet-01"` | no |
| <a name="input_subnet_01_region"></a> [subnet\_01\_region](#input\_subnet\_01\_region) | Region of the first subnet. | `string` | `"us-central1"` | no |
| <a name="input_subnet_02_description"></a> [subnet\_02\_description](#input\_subnet\_02\_description) | Description of the second subnet. | `string` | `"subnet 02"` | no |
| <a name="input_subnet_02_ip"></a> [subnet\_02\_ip](#input\_subnet\_02\_ip) | CIDR of the second subnet. | `string` | `"10.12.0.0/22"` | no |
| <a name="input_subnet_02_name"></a> [subnet\_02\_name](#input\_subnet\_02\_name) | Name of the second subnet in the VPC network. | `string` | `"gke-vpc-subnet-02"` | no |
| <a name="input_subnet_02_region"></a> [subnet\_02\_region](#input\_subnet\_02\_region) | Region of the second subnet. | `string` | `"us-west2"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_project_ids"></a> [project\_ids](#output\_project\_ids) | n/a |

[gitops]: https://about.gitlab.com/topics/gitops/
[repo-sync]: https://cloud.google.com/anthos-config-management/docs/reference/rootsync-reposync-fields
[root-sync]: https://cloud.google.com/anthos-config-management/docs/reference/rootsync-reposync-fields
[config-sync]: https://cloud.google.com/anthos-config-management/docs/config-sync-overview
[cloud-deploy]: https://cloud.google.com/deploy?hl=en
[terraform]: https://www.terraform.io/
[gke]: https://cloud.google.com/kubernetes-engine?hl=en
[git]: https://git-scm.com/
[github]: https://github.com/
[gcp-project]: https://cloud.google.com/resource-manager/docs/creating-managing-projects
[personal-access-token]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
[machine-user-account]: https://docs.github.com/en/get-started/learning-about-github/types-of-github-accounts