# Chatbot Application with LangChain, persistent storage and IAP

## Introduction

It is important to make AI models accessible to end-users through applications that provide a user-friendly interface.

In this tutorial, you will learn how to deploy a chatbot application using LangChain and Streamlit on Google Cloud Platform (GCP).

The application can be used to interact with any language model served on an OpenAI-compatible API; for example, you can use Gemma2 model deployed on Google Kubernetes Engine (GKE) using Kserve, as described in the [Kserve README](../kserve/README.md).

The application will be deployed on GCP using Terraform, and secured with Identity Aware Proxy (IAP).

Finally, it will use user identity provided by IAP and store each user's messages in a Cloud SQL PostgreSQL database.

### What is LangChain?

LangChain is a framework designed to simplify the integration of language models into applications. It provides tools and abstractions to manage the complexities of working with language models, making it easier to build, deploy and maintain AI-powered applications.

### What is Streamlit?

Streamlit is an open-source app framework used to create interactive web applications for machine learning and data science projects. It allows developers to build and deploy powerful data-driven applications with minimal effort.

### What is Identity Aware Proxy (IAP)?

Identity Aware Proxy (IAP) is a Google Cloud service that provides secure access to applications running on GCP. It allows you to control access to your applications based on user identity, ensuring that only authorized users can access your resources. You can learn more about IAP [here](https://cloud.google.com/iap).

## Prerequisites

Before you begin, ensure you have the following:

- A Google Cloud Platform account and project
- The Google Cloud SDK (gcloud) installed and configured
- Terraform installed on your local machine
- A language model deployed on an OpenAI-compatible API

> **Note:** Follow the instructions provided in the [Kserve README](../kserve/README.md) to deploy your model on Google Kubernetes Engine (GKE).

## Instructions

1. **Optional: Build and Run the Application Locally**

   You can optionally set up a local PostgreSQL instance to test the application locally.

   Start by creating network, then run the PostgreSQL container:

   ```bash
   docker network create langchain-chatbot
   docker run --rm --name postgres --network langchain-chatbot -e POSTGRES_PASSWORD=superpassword -d postgres
   ```

   Next, build and run the application:

   ```bash
   docker build -t langchain-chatbot app
   docker run --rm --name chatbot \
     --network langchain-chatbot -p 8501:8501 \
     -e MODEL_BASE_URL=https://model.example.com/openai/v1/ \
     -e MODEL_NAME=gemma2 \
     -e DB_URI=postgresql://postgres:superpassword@postgres:5432/postgres \
     langchain-chatbot
   ```

2. **Create Google Container Registry (GCR)**

   Enable the Artifact Registry API and create a Docker repository:

   ```bash
   gcloud services enable artifactregistry.googleapis.com
   gcloud artifacts repositories create langchain-chatbot \
     --repository-format=docker \
     --location=us-central1
   ```

3. **Build the Application Using Cloud Build**

   Edit cloudbuild.yaml to reference the newly created repository, then submit the build:

   ```bash
   gcloud builds submit app
   ```

4. **Ensure IAP and OAuth Consent Screen are Configured**

   Before securing the application with Identity Aware Proxy (IAP), ensure that the OAuth consent screen is configured. Go to the [IAP page](https://console.cloud.google.com/security/iap) and click "Configure consent screen" if prompted.

   Next, create an OAuth 2.0 client ID by visiting the [Credentials page](https://console.cloud.google.com/apis/credentials). Save the client ID and secret for later use. Also add the redirect URI to the OAuth 2.0 client as follows: `https://iap.googleapis.com/v1/oauth/clientIds/<CLIENT_ID>:handleRedirect`.

5. **Apply Terraform Configuration**

   Go to terraform dir, make a copy of `terraform.tfvars.example` and adjust the variables for the Terraform configuration. The minimum required variables are:

   - `project_id` - your GCP project ID
   - `model_base_url` and `model_name` - where to find the model
   - `k8s_app_image` - the name and tag of the Docker image built previously
   - `support_email`, `oauth_client_id`, `oauth_client_secret` and `members_allowlist` - for IAP configuration

   Initialize and apply the Terraform configuration to set up the necessary infrastructure.

   ```bash
   terraform init
   terraform apply -var-file=terraform.tfvars
   ```

   It will do the following:

   - Create a PostgreSQL instance along with a database
   - Connect the PostgreSQL instance to the network you specified using VPC Peering
   - Create Deployment and Service resources for the application in the specified namespace of your GKE cluster
   - Configure IAP to secure the application

   When the Terraform run completes, it will output the URL of the application. Note that it may take some time for the application to become available as provisioning of the Managed Certificate can take a few minutes.

## Conclusion

By following these steps, you will be able to deploy the LangChain Chatbot on GCP, leveraging the power of language models to create an interactive and intelligent application.
