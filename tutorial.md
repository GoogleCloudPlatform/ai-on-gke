## Let's get started!

Welcome to the Cloudshell tutorial for AI on GKE!

This guide will show you how to prepare GKE cluster and install the AI applications on GKE. It'll also walk you through the files that needs your inputs and commands that will complete the tutorial.

Add more summary here

**Time to complete**: About 20 minutes

**Prerequisites**: A Cloud Billing account

Click the **Continue** button to move to the next step.

## What is AI-on-GKE

The AI-on-GKE provides Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries.



Next, you'll provide inputs parameters and launch a AI-on-GKE tutorial.

## Step 1: Provide Inputs Parameters for Terraform

Here on step 1 you need to update the terraform tfvars file to provide the input parameters to allow terraform code execution to provision GKE resource and deploy your applications. The will include the inputs parameters in form of key value pairs. Update the values as per your requirements.

<walkthrough-editor-open-file filePath="terraform.tfvars"> Open terraform.tfvars 
</walkthrough-editor-open-file>


**Tip**: Click the highlighted text above to open the file on your cloudshell.


## Step 2: [Optional] Configure Terraform GCS backend

You can also configure the GCS bucket to persist the terraform state file for further usage. To configure the terraform backend you need to have GCS bucket already created.

### [Optional] Create GCS Bucket 
In case you dont have GCS bucket already, you can create using terraform or gcloud command as well. Refer below for gcloud command line to create new GCS bucket.
```bash
gcloud storage buckets create gs://BUCKET_NAME
```
**Tip**: Click the copy button on the side of the code box to paste the command in the Cloud Shell terminal to run it.


### Modify Terraform State Backend

Modify the backend.tf and uncomment the code and update the backend bucket name.
<walkthrough-editor-open-file filePath="backend.tf"> Open backend.tf 
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

## Step 3: Run Terraform Apply using Cloud Build

You are ready to deploy your resources now! `cloudbuild.yaml` is already prepared with all the steps requires to deploy the application. 

Run the below command to submit cloudbuild job to deploy the resources:
```bash
gcloud beta builds submit
```

Monitor the terminal for the log link and status for cloud build jobs.

## Congratulations

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

You're all set!

You can now access your cluster and applications.


