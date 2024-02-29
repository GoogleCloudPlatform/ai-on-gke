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

| Name | Version |
|------|---------|
| <a name="requirement_google"></a> [google](#requirement\_google) | 4.72.1 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | 4.72.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cloud-nat"></a> [cloud-nat](#module\_cloud-nat) | ./modules/cloud-nat | n/a |
| <a name="module_create-vpc"></a> [create-vpc](#module\_create-vpc) | ./modules/network | n/a |
| <a name="module_gke"></a> [gke](#module\_gke) | ./modules/cluster | n/a |
| <a name="module_node_pool-ondemand"></a> [node\_pool-ondemand](#module\_node\_pool-ondemand) | ./modules/node-pools | n/a |
| <a name="module_node_pool-reserved"></a> [node\_pool-reserved](#module\_node\_pool-reserved) | ./modules/node-pools | n/a |
| <a name="module_node_pool-spot"></a> [node\_pool-spot](#module\_node\_pool-spot) | ./modules/node-pools | n/a |
| <a name="module_reservation"></a> [reservation](#module\_reservation) | ./modules/vm-reservations | n/a |

## Inputs

| Name | Description | Type | Default                                                                                                                                                           | Required |
|------|-------------|------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the GKE cluster | `string` | `"gke-ml"`                                                                                                                                                        |    no    |
| <a name="input_lookup_state_bucket"></a> [lookup\_state\_bucket](#input\_lookup\_state\_bucket) | GCS bucket to look up TF state from previous steps. | `string` | n/a                                                                                                                                                               |   yes    |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | VPC network where GKE cluster will be created | `string` | `"ml-vpc"`                                                                                                                                                        |    no    |
| <a name="input_ondemand_taints"></a> [ondemand\_taints](#input\_ondemand\_taints) | Taints to be applied to the on-demand node pool. | <pre>list(object({<br>    key    = string<br>    value  = any<br>    effect = string<br>  }))</pre> | <pre>[<br>  {<br>    "effect": "NO_SCHEDULE",<br>    "key": "ondemand",<br>    "value": true<br>  }<br>]</pre>                                                    |    no    |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project where the resources will be created. It is a map with environments a skeys and project\_ids s values | `map` | n/a <pre> An example : </br> project_id = {<br>  "dev": "gkebatchexpce3c8dcb",<br>  "prod": "gkebatchexpce3c8dcb",<br>  "staging": "gkebatchexpce3c8dcb"<br>}</pre> |   yes    |
| <a name="input_reserved_taints"></a> [reserved\_taints](#input\_reserved\_taints) | Taints to be applied to the reserved node pool. | <pre>list(object({<br>    key    = string<br>    value  = any<br>    effect = string<br>  }))</pre> | <pre>[<br>  {<br>    "effect": "NO_SCHEDULE",<br>    "key": "reserved",<br>    "value": true<br>  }<br>]</pre>                                                    |    no    |
| <a name="input_routing_mode"></a> [routing\_mode](#input\_routing\_mode) | VPC routing mode. | `string` | `"GLOBAL"`                                                                                                                                                        |    no    |
| <a name="input_spot_taints"></a> [spot\_taints](#input\_spot\_taints) | Taints to be applied to the spot node pool. | <pre>list(object({<br>    key    = string<br>    value  = any<br>    effect = string<br>  }))</pre> | <pre>[<br>  {<br>    "effect": "NO_SCHEDULE",<br>    "key": "spot",<br>    "value": true<br>  }<br>]</pre>                                                        |    no    |
| <a name="input_subnet_01_description"></a> [subnet\_01\_description](#input\_subnet\_01\_description) | Description of the first subnet. | `string` | `"subnet 01"`                                                                                                                                                     |    no    |
| <a name="input_subnet_01_ip"></a> [subnet\_01\_ip](#input\_subnet\_01\_ip) | CIDR of the first subnet. | `string` | `"10.40.0.0/22"`                                                                                                                                                  |    no    |
| <a name="input_subnet_01_name"></a> [subnet\_01\_name](#input\_subnet\_01\_name) | Name of the first subnet in the VPC network. | `string` | `"ml-vpc-subnet-01"`                                                                                                                                       |    no    |
| <a name="input_subnet_01_region"></a> [subnet\_01\_region](#input\_subnet\_01\_region) | Region of the first subnet. | `string` | `"us-central1"`                                                                                                                                                   |    no    |
| <a name="input_subnet_02_description"></a> [subnet\_02\_description](#input\_subnet\_02\_description) | Description of the second subnet. | `string` | `"subnet 02"`                                                                                                                                                     |    no    |
| <a name="input_subnet_02_ip"></a> [subnet\_02\_ip](#input\_subnet\_02\_ip) | CIDR of the second subnet. | `string` | `"10.12.0.0/22"`                                                                                                                                                  |    no    |
| <a name="input_subnet_02_name"></a> [subnet\_02\_name](#input\_subnet\_02\_name) | Name of the second subnet in the VPC network. | `string` | `"gke-vpc-subnet-02"`                                                                                                                                  |    no    |
| <a name="input_subnet_02_region"></a> [subnet\_02\_region](#input\_subnet\_02\_region) | Region of the second subnet. | `string` | `"us-west2"`                                                                                                                                                      |    no    |

## Outputs

| Name | Description      |
|------|------------------|
| <a name="output_gke_cluster"></a> [gke\_cluster](#output\_gke\_cluster) | GKE cluster info |

## Prerequisite
To run this Terraform Module, you need to have the following IAM roles on the projects where the GKE clusters will be created:
- roles/Owner
 
## Usage
- Skip this step if you have run [01_gcp_project][projects] to create GCP projects. If you are starting from this module, run these steps.
  - Create a new GCP project that will host the TF state bucket or use an existing project.
    - To create a new project, open `cloudshell` and run the following command:
      ```
      gcloud projects create <PROJECT_ID>
      ```
    - Associate billing account to the project
      ```
      gcloud beta billing projects link <PROJECT_ID> \
      --billing-account <BILLING_ACCOUNT_ID>
      ```

  - Create a GCS bucket in the project for storing TF state.
    - To create a new bucket, run the following command in `cloudshell`
      ```
       gcloud storage buckets create gs://<PROJECT_ID>-tf-state --location=<REGION>  --project <PROJECT_ID>
      ```
- Clone the repo and change dir
  ```
  git clone https://github.com/GoogleCloudPlatform/ai-on-gke
  cd ml-platform/02_gke
  ```   
- In backend.tf replace `YOUR_STATE_BUCKET` with the name of the GCS bucket.
- In variables.tf, provide the values of the following variables:
  - `project_id` : If you created the projects using [01_gcp_project][projects] module, no need to provide a value for it as TF will read the project ids from the state file.
                   If you are providing your existing project ids, provide it in the following format.
    
      The following is an example of creating three env in the same GCP project :
       ```
       { "dev" : "project1", "staging" : "project1", "prod" : "project1" }
       ``` 
    The following is an example of creating three env in three different projects:
     ```
     { "dev" : "project1", "staging" : "project2", "prod" : "project3" }
     ```     
    
  - `lookup_state_bucket` : provide the name of the GCS bucket.
  

- If you did not use [01_gcp_projects][projects] module to create GCP projects and are supplying your project ids in variables.tf, enable the following APIs in those project.
  - In `cloudshell`, run:
     ```
      gcloud config set project <PROJECT_ID>
    
      gcloud services enable cloudresourcemanager.googleapis.com iam.googleapis.com container.googleapis.com gkehub.googleapis.com  anthos.googleapis.com anthosconfigmanagement.googleapis.com compute.googleapis.com 
     ```
  
- terraform init
- terraform plan
- terraform apply --auto-approve

When Terraform apply has been completed, you will get the following resources:
- A VPC network per environment with a NAT gateway and Cloud router.
- A private GKE cluster per environment. This cluster will be created in the respective VPC.
- VM reservation for `nvidia-l4`
- Three node pools, spot, reserved and on-demand respectively.
<!-- END_TF_DOCS -->

## Clean up

1. The easiest way to prevent continued billing for the resources that you created for this tutorial is to delete the project you created for the tutorial. Run the following commands from Cloud Shell:

   ```bash
    gcloud config unset project && \
    echo y | gcloud projects delete <PROJECT_ID>
   ```

2. If the project needs to be left intact, another option is to destroy the infrastructure created from this module. Note, this does not destroy the Cloud Storage bucket containing the Terraform state and service enablement created out of Terraform.

   ```bash
    cd ml-platform/02_gke && \
    terraform destroy --auto-approve
   ```

[projects]: ../01_gcp_project/README.md