## Let's get started!

Welcome to the Cloudshell tutorial for AI on GKE!

This guide will show you how to prepare a GKE cluster and install the AI applications on GKE. It'll also walk you through the configuration files that can be provided with custom inputs and commands that will complete the tutorial.

**Time to complete**: About 30 minutes

**Prerequisites**: GCP project linked with a Cloud Billing account

To begin, click **Start**.

## What is AI-on-GKE

This tutorial Terraform & Cloud Build to provision the infrastructure as well as deploy the workloads

You'll be performing the following activities:

1. Set project-id for gcloud CLI
2. Update terraform variable values to create infrastructure
3. Update terraform variable values to provide workload configuration
4. Create a GCS bucket to store terraform state
5. Configure service account to be used for deployment
6. Submit Cloud build job to create infrastructure & deploy workloads

To get started, click **Next**.

## Step 0: Set your project
To set your Cloud Platform project for this terminal session use:
```bash
gcloud config set project [PROJECT_ID]
```
All the resources will be created in this project

## Step 1: Provide PLATFORM Inputs Parameters for Terraform

Here on step 1 you need to update the PLATFORM terraform tfvars file (located in ./platform/platform.tfvars) to provide the input parameters to allow terraform code execution to provision GKE resources. This will include the input parameters in the form of key value pairs. Update the values as per your requirements.

<walkthrough-editor-open-file filePath="./platform/platform.tfvars"> Open platform.tfvars 
</walkthrough-editor-open-file>

Update `project_id` and review the other default values.

**Tip**: Click the highlighted text above to open the file in your cloudshell editor.

You can find tfvars examples in the tfvars_examples folder.


## Step 2: Provide APPLICATION Inputs Parameters for Terraform

Here on step 2 you need to update the APPLICATION terraform tfvars file (located in ./workloads/workloads.tfvars) to provide the input parameters to allow terraform code execution to provision the APPLICATION WORKLOADS. This will include the input parameters in the form of key value pairs. Update the values as per your requirements.

<walkthrough-editor-open-file filePath="./workloads/workloads.tfvars"> Open workloads.tfvars
</walkthrough-editor-open-file>

Update `project_id` and review the other default values.

**Tip**: Click the highlighted text above to open the file on your cloudshell.


## Step 3: [Optional] Configure Terraform GCS backend

You can also configure the GCS bucket to persist the terraform state file for further usage. To configure the terraform backend you need to have a GCS bucket already created.
This needs to be done both for PLATFORM and APPLICATION stages.

### [Optional] Create GCS Bucket 
In case you don't have a GCS bucket already, you can create using terraform or gcloud command as well. Refer below for the gcloud command line to create a new GCS bucket.
```bash
gcloud storage buckets create gs://BUCKET_NAME
```
**Tip**: Click the copy button on the side of the code box to paste the command in the Cloud Shell terminal to run it.


### [Optional] Modify PLATFORM Terraform State Backend

Modify the ./platform/backend.tf and uncomment the code and update the backend bucket name.
<walkthrough-editor-open-file filePath="./platform/backend.tf"> Open ./platform/backend.tf 
</walkthrough-editor-open-file>

After changes file will look like below:
```terraform
terraform {
 backend "gcs" {
   bucket  = "BUCKET_NAME"
   prefix  = "terraform/state"
 }
}
```

Refer [here](https://cloud.google.com/docs/terraform/resource-management/store-state) for more details. 


###  [Optional] APPLICATION Terraform State Backend

Modify the ./workloads/backend.tf and uncomment the code and update the backend bucket name.
<walkthrough-editor-open-file filePath="./workloads/backend.tf"> Open ./workloads/backend.tf
</walkthrough-editor-open-file>

After changes file will look like below:
```terraform
terraform {
 backend "gcs" {
   bucket  = "BUCKET_NAME"
   prefix  = "terraform/state/workloads"
 }
}
```

Refer [here](https://cloud.google.com/docs/terraform/resource-management/store-state) for more details. 

## Step 4: Configure Cloud Build Service Account

The Cloud Build service that orchestrates the environment creation requires a Service Account. Please run the following steps to create it and grant the roles required for deployment.
```bash
export PROJECT_ID=$(gcloud config get-value project)
gcloud iam service-accounts create aiongke --display-name="AI on GKE Service Account"
./iam/iam_policy.sh
```


## Step 5: Run Terraform Apply using Cloud Build

You are ready to deploy your resources now! `cloudbuild.yaml` is already prepared with all the steps required to deploy the application. 

Run the below command to submit Cloud Build job to deploy the resources:


```bash
gcloud beta builds submit --config=cloudbuild.yaml --substitutions=_PLATFORM_VAR_FILE="platform.tfvars",_WORKLOADS_VAR_FILE="workloads.tfvars"
```

Monitor the terminal for the log link and status for cloud build jobs.

## Step 6: [Optional] Delete resources created

You can now delete the resources


```bash
gcloud beta builds submit --config=cloudbuild_delete.yaml  --substitutions=_PLATFORM_VAR_FILE="platform.tfvars",_WORKLOADS_VAR_FILE="workloads.tfvars"
```


Monitor the terminal for the log link and status for cloud build jobs.


## Congratulations

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

You're all set!

You can now access your cluster and applications.


