GKE Marketplace offering for Jupyterhub 

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project\_id | GCP project id | `string` |  | yes |
| cluster\_name | Existing cluster to be used for deployment | `string` |  | yes |
| cluster\_location | Region name | `string` |  | yes |
| jupyterhub\_namespace | GKE namespace to deploy to. Creates namespace if not present | `string` |  | yes |


## Outputs

| Name | Description |
|------|-------------|
| endpoint | endpoint to access jupyterhub |
| user | Admin username |
| password | Password for the admin user |
