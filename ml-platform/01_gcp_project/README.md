<!--
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
-->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_google"></a> [google](#requirement\_google) | 4.72.1 |


## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_gcp-project"></a> [gcp-project](#module\_gcp-project) | ./modules/projects | n/a |


## Inputs

| Name                                                                              | Description                                      | Type | Default                      | Required |
|-----------------------------------------------------------------------------------|--------------------------------------------------|------|------------------------------|:--------:|
| <a name="input_billing_account"></a> [billing\_account](#input\_billing\_account) | GCP billing account                              | `string` | n/a                          |   yes    |
| <a name="input_env"></a> [env](#input\_env)                                       | List of environments                             | `set(string)` | <pre>[<br>  "dev"<br>]</pre> |    no    |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id)                   | Folder Id where the GCP projects will be created | `string` | `null`                       |    no    |
| <a name="input_org_id"></a> [org\_id](#input\_org\_id)                            | The GCP orig id                                  | `string` | n/a                          |   yes    |
| <a name="project_name"></a> [project\_name](#input\_project\_name)                | Project name                                     | `string` | `ml-platfrom`                |    no    |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_project_ids"></a> [project\_ids](#output\_project\_ids) | n/a |
<!-- END_TF_DOCS -->

## Workflow

This module accepts a list of environments and creates a GCP project for each environment. 

Typically, you would want to have dev, staging and production environments created in separate projects. To have such isolation, pass `env` input variable as `[ "dev", "staging", "prod" ]`. This will create one project for dev, staging and prod environments. You can update the input variable `env` based on how many environments/projects you want to create.

However, if you want to use a single project for multiple environments, you can create just one project by passing one element to `env` input variable list e.g [ "dev" ] or ["my-playground"] etc.

## Prerequisite
To run this Terraform Module, you need to have the following IAM roles:
- roles/resourcemanager.projectCreator

## Usage

- Create a new GCP project that will host the TF state bucket.
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
  cd ml-platform/01_gcp_project
  ```   
- In backend.tf replace `YOUR_STATE_BUCKET` with the name of the GCS bucket.
- In variables.tf:
  - replace `YOUR_GCP_ORG_ID` with your GCP Org ID.
  - replace `YOUR_BILLING_ACCOUNT` with GCP your Billing account.
  - (optional) overridde the default value of `folder_id` with the numeric ID of the folder this project should be created under. If you leave `folder_id` null, the projects will bw created under your org.
  - (optional) override the default value of `env`. See [workflow](#workflow) for details.

- terraform init
- terraform plan
- terraform apply --auto-approve


## Clean up

1. The easiest way to prevent continued billing for the resources that you created for this tutorial is to delete the project you created for the tutorial. Run the following commands from Cloud Shell:

   ```bash
    gcloud config unset project && \
    echo y | gcloud projects delete <PROJECT_ID>
   ```

2. If the project needs to be left intact, another option is to destroy the infrastructure created from this module. Note, this does not destroy the Cloud Storage bucket containing the Terraform state and service enablement created out of Terraform.

   ```bash
    cd ml-platform/01_gcp_project && \
    terraform destroy --auto-approve
   ```